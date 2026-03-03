import { useState, useEffect } from "react";

// ── Google Sheets config ─────────────────────────────────────────────────────
const SPREADSHEET_ID = "1VyiT1pdy9_JyqGdzxuqMO2Ksl2LXL8YU";

function csvUrl(sheet) {
  return "https://docs.google.com/spreadsheets/d/" + SPREADSHEET_ID + "/gviz/tq?tqx=out:csv&sheet=" + encodeURIComponent(sheet);
}

async function fetchCSV(sheet) {
  const res = await fetch(csvUrl(sheet));
  if (!res.ok) throw new Error("Failed to fetch tab: " + sheet);
  return csvToRows(await res.text());
}

function csvToRows(text) {
  const rows = [];
  let row = [], cur = "", inQ = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i], next = text[i + 1];
    if (inQ) {
      if (ch === '"' && next === '"') { cur += '"'; i++; }
      else if (ch === '"') inQ = false;
      else cur += ch;
    } else {
      if (ch === '"') inQ = true;
      else if (ch === ',') { row.push(cur.trim()); cur = ""; }
      else if (ch === '\n' || ch === '\r') {
        if (cur || row.length) { row.push(cur.trim()); rows.push(row); row = []; cur = ""; }
        if (ch === '\r' && next === '\n') i++;
      } else cur += ch;
    }
  }
  if (cur || row.length) { row.push(cur.trim()); rows.push(row); }
  return rows;
}

function parseProjectsTab(rows) {
  if (rows.length < 2) return [];
  const headers = rows[0].map(h => h.toLowerCase().trim());
  return rows.slice(1).filter(r => r.some(c => c)).map(r => {
    const get = k => r[headers.indexOf(k)] || "";
    return {
      id: get("id") || String(Math.random()),
      group: get("group"),
      name: get("project name"),
      description: get("description"),
      owner: get("owner"),
      priority: get("priority"),
      timeline: get("timeline"),
      status: get("status"),
      deadline: get("deadline"),
      budget: get("budget"),
    };
  }).filter(p => p.name);
}

function parseProjectTab(rows) {
  const data = {
    overview: { objective: "", strategicPriority: "", successCriteria: "", owner: "", priority: "", status: "", timeline: "", deadline: "", budget: "" },
    phases: [], keySuccesses: [], stakeholders: [], meetings: [],
    dependencies: { internal: [], external: [], risks: [] },
    budget_items: [], statusUpdates: [],
  };
  let section = null;
  for (const row of rows) {
    const a = (row[0] || "").trim();
    const aLow = a.toLowerCase().replace(/\[.*?\]/g, "").trim();
    if (aLow.startsWith("overview")) { section = "overview"; continue; }
    if (aLow.startsWith("phases")) { section = "phases"; continue; }
    if (aLow.startsWith("key successes")) { section = "successes"; continue; }
    if (aLow.startsWith("stakeholders")) { section = "stakeholders"; continue; }
    if (aLow.startsWith("meetings")) { section = "meetings"; continue; }
    if (aLow.startsWith("dependencies")) { section = "dependencies"; continue; }
    if (aLow.startsWith("project budget")) { section = "budget"; continue; }
    if (aLow.startsWith("status updates")) { section = "updates"; continue; }
    if (row.every(c => !c)) continue;
    const isHeader = ["timeline","name","date (yyyy-mm-dd)","achievement","type","description","#","date"].includes(a.toLowerCase());
    if (isHeader) continue;
    if (section === "overview") {
      const key = a.toLowerCase(), val = (row[1] || "").trim();
      if (key.includes("objective")) data.overview.objective = val;
      else if (key.includes("strategic")) data.overview.strategicPriority = val;
      else if (key.includes("success crit")) data.overview.successCriteria = val;
      else if (key === "owner") data.overview.owner = val;
      else if (key === "priority") data.overview.priority = val;
      else if (key === "status") data.overview.status = val;
      else if (key === "timeline") data.overview.timeline = val;
      else if (key === "deadline") data.overview.deadline = val;
      else if (key === "budget") data.overview.budget = val;
    } else if (section === "phases" && row[0]) {
      data.phases.push({ timeline: row[0]||"", checkpoint: row[1]||"", deliverable: row[2]||"", owner: row[3]||"", status: row[4]||"" });
    } else if (section === "successes" && row[0]) {
      data.keySuccesses.push({ achievement: row[0]||"", target: row[1]||"", measure: row[2]||"", owner: row[3]||"" });
    } else if (section === "stakeholders" && row[1]) {
      data.stakeholders.push({ name: row[1]||"", department: row[2]||"", role: row[3]||"", involvement: row[4]||"", communication: row[5]||"" });
    } else if (section === "meetings" && row[0]) {
      data.meetings.push({ date: row[0]||"", title: row[1]||"", attendees: row[2]||"", notes: row[3]||"" });
    } else if (section === "dependencies" && row[1]) {
      const type = (row[0] || "").toLowerCase();
      if (type.includes("internal")) data.dependencies.internal.push(row[1]);
      else if (type.includes("external")) data.dependencies.external.push(row[1]);
      else if (type.includes("risk")) data.dependencies.risks.push(row[1]);
    } else if (section === "updates" && row[0]) {
      data.statusUpdates.push({ date: row[0]||"", notes: row[1]||"" });
    }
  }
  return data;
}

// ── Constants ────────────────────────────────────────────────────────────────
const GOLD   = "#CFB87C";
const BLACK  = "#1a1a1a";
const DARK   = "#111";
const CARD   = "#1e1e1e";
const BORDER = "#2e2e2e";

const STATUS_COLORS = {
  "On Track":    { bg: "#16a34a", text: "#fff" },
  "In Progress": { bg: "#d97706", text: "#fff" },
  "Not Started": { bg: "#6b7280", text: "#fff" },
  "Complete":    { bg: "#0ea5e9", text: "#fff" },
  "At Risk":     { bg: "#dc2626", text: "#fff" },
  "On Hold":     { bg: "#7c3aed", text: "#fff" },
};

const PRIORITY_COLORS = {
  "High":   { bg: "#dc2626", text: "#fff" },
  "Medium": { bg: "#d97706", text: "#fff" },
  "Low":    { bg: "#16a34a", text: "#fff" },
};

const GROUP_COLORS = {
  "Executive Team": GOLD,
  "Operations":     "#60a5fa",
  "Compliance":     "#f472b6",
};

// ── Name matching ────────────────────────────────────────────────────────────
function nameMatcher(query) {
  const q = query.trim().toLowerCase();
  const parts = q.split(/\s+/);
  return function(str) {
    if (!str) return false;
    const s = str.toLowerCase();
    if (s.includes(q)) return true;
    if (parts.length === 1) {
      return s.split(/[,\/]/).some(function(token) { return token.trim().split(/\s+/)[0] === parts[0]; });
    }
    return false;
  };
}

// ── Shared components ────────────────────────────────────────────────────────
function StatusBadge({ status, small }) {
  const c = STATUS_COLORS[status] || { bg: "#6b7280", text: "#fff" };
  return (
    <span style={{ background: c.bg, color: c.text, padding: small ? "2px 8px" : "3px 10px", borderRadius: 4, fontSize: small ? 11 : 12, fontWeight: 600, fontFamily: "'DM Mono', monospace", letterSpacing: "0.04em", whiteSpace: "nowrap" }}>
      {status}
    </span>
  );
}

function PriorityBadge({ priority }) {
  const c = PRIORITY_COLORS[priority] || { bg: "#6b7280", text: "#fff" };
  return (
    <span style={{ background: c.bg, color: c.text, padding: "3px 10px", borderRadius: 4, fontSize: 12, fontWeight: 600, fontFamily: "'DM Mono', monospace", whiteSpace: "nowrap" }}>
      {priority}
    </span>
  );
}

function SectionTitle({ children }) {
  return (
    <div style={{ fontFamily: "'DM Mono', monospace", fontSize: 11, letterSpacing: "0.15em", color: GOLD, textTransform: "uppercase", marginBottom: 12, marginTop: 24, display: "flex", alignItems: "center", gap: 10 }}>
      <div style={{ width: 3, height: 14, background: GOLD, borderRadius: 2 }} />
      {children}
    </div>
  );
}

function DataTable({ headers, rows }) {
  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
        <thead>
          <tr>
            {headers.map((h, i) => (
              <th key={i} style={{ textAlign: "left", padding: "8px 12px", background: "#252525", color: "#999", fontFamily: "'DM Mono', monospace", fontSize: 11, letterSpacing: "0.08em", textTransform: "uppercase", borderBottom: "1px solid " + BORDER }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri} style={{ borderBottom: "1px solid " + BORDER }}>
              {row.map((cell, ci) => (
                <td key={ci} style={{ padding: "9px 12px", color: "#ccc", fontFamily: "'Crimson Pro', Georgia, serif", fontSize: 14, verticalAlign: "top", maxWidth: 260, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ── Project Detail ───────────────────────────────────────────────────────────
function ProjectDetail({ project, onBack }) {
  const [activeTab, setActiveTab] = useState("overview");
  const tabs = ["overview","phases","successes","stakeholders","meetings","dependencies","budget","updates"];
  const today = new Date(); today.setHours(0,0,0,0);
  const upcomingMeetings = (project.meetings||[]).filter(m => new Date(m.date) >= today).sort((a,b) => new Date(a.date)-new Date(b.date));
  const pastMeetings     = (project.meetings||[]).filter(m => new Date(m.date) < today).sort((a,b) => new Date(b.date)-new Date(a.date));
  const getUrg = d => { const diff=(new Date(d)-today)/86400000; return diff<=3?"urgent":diff<=7?"soon":"normal"; };
  const fmtDate = d => new Date(d).toLocaleDateString("en-US",{weekday:"short",month:"short",day:"numeric",year:"numeric"});
  const daysUntil = d => { const diff=Math.ceil((new Date(d)-today)/86400000); return diff===0?"Today":diff===1?"Tomorrow":"In "+diff+" days"; };
  const urgentCount = upcomingMeetings.filter(m => getUrg(m.date) !== "normal").length;
  const groupColor = GROUP_COLORS[project.group] || GOLD;

  return (
    <div style={{ minHeight:"100vh", background:DARK, color:"#e5e5e5" }}>
      <div style={{ background:BLACK, borderBottom:"1px solid "+BORDER, padding:"0 32px", position:"sticky", top:0, zIndex:10 }}>
        <div style={{ display:"flex", alignItems:"center", gap:16, padding:"14px 0" }}>
          <button onClick={onBack} style={{ background:"none", border:"1px solid "+BORDER, color:"#aaa", cursor:"pointer", borderRadius:6, padding:"6px 14px", fontFamily:"'DM Mono', monospace", fontSize:12 }}>
            &larr; Back
          </button>
          <div style={{ width:1, height:20, background:BORDER }} />
          <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:groupColor, letterSpacing:"0.1em" }}>{project.group}</div>
          <div style={{ color:BORDER }}>/</div>
          <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:18, color:"#fff", fontWeight:700, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", maxWidth:360 }}>{project.name}</div>
          <div style={{ marginLeft:"auto", display:"flex", gap:8, alignItems:"center" }}>
            <PriorityBadge priority={project.priority} />
            <StatusBadge status={project.status} />
          </div>
        </div>
        <div style={{ display:"flex", borderTop:"1px solid "+BORDER }}>
          {tabs.map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)} style={{ background:"none", border:"none", borderBottom:activeTab===tab?"2px solid "+GOLD:"2px solid transparent", color:activeTab===tab?GOLD:"#666", padding:"10px 18px", cursor:"pointer", fontFamily:"'DM Mono', monospace", fontSize:12, textTransform:"capitalize", letterSpacing:"0.05em", display:"flex", alignItems:"center", gap:6 }}>
              {tab}
              {tab==="meetings" && urgentCount>0 && (
                <span style={{ background:"#dc2626", color:"#fff", borderRadius:"50%", width:16, height:16, fontSize:10, fontWeight:700, display:"flex", alignItems:"center", justifyContent:"center" }}>{urgentCount}</span>
              )}
            </button>
          ))}
        </div>
      </div>

      <div style={{ padding:"32px", maxWidth:1100, margin:"0 auto" }}>

        {activeTab === "overview" && (
          <div>
            <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:16, marginBottom:28 }}>
              {[{label:"Owner",value:project.owner},{label:"Timeline",value:project.timeline},{label:"Deadline",value:project.deadline},{label:"Budget",value:project.budget},{label:"Priority",value:<PriorityBadge priority={project.priority}/>},{label:"Status",value:<StatusBadge status={project.status}/>}].map((item,i) => (
                <div key={i} style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, padding:"16px 20px" }}>
                  <div style={{ fontFamily:"'DM Mono', monospace", fontSize:10, color:"#666", letterSpacing:"0.1em", textTransform:"uppercase", marginBottom:6 }}>{item.label}</div>
                  <div style={{ fontSize:15, color:"#ddd" }}>{item.value}</div>
                </div>
              ))}
            </div>
            <SectionTitle>Overview</SectionTitle>
            <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, overflow:"hidden" }}>
              {[["Objective",project.overview.objective],["Strategic Priority",project.overview.strategicPriority],["Success Criteria",project.overview.successCriteria]].map(([label,value],i,arr) => (
                <div key={i} style={{ display:"grid", gridTemplateColumns:"180px 1fr", borderBottom:i<arr.length-1?"1px solid "+BORDER:"none" }}>
                  <div style={{ padding:"14px 20px", background:"#252525", fontFamily:"'DM Mono', monospace", fontSize:12, color:"#888", borderRight:"1px solid "+BORDER }}>{label}</div>
                  <div style={{ padding:"14px 20px", fontSize:15, color:"#ccc" }}>{value || <span style={{ color:"#444", fontStyle:"italic" }}>--</span>}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === "phases" && (
          <div>
            <SectionTitle>Project Phases</SectionTitle>
            {project.phases.length === 0
              ? <div style={{ color:"#555", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No phases defined yet.</div>
              : <DataTable headers={["Timeline","Checkpoint","Deliverable","Owner","Status"]} rows={project.phases.map(p => [
                  <span style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:GOLD }}>{p.timeline}</span>,
                  p.checkpoint, p.deliverable||"--", p.owner, <StatusBadge status={p.status} small/>
                ])} />
            }
          </div>
        )}

        {activeTab === "successes" && (
          <div>
            <SectionTitle>Key Successes</SectionTitle>
            {project.keySuccesses.length === 0
              ? <div style={{ color:"#555", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No key successes defined yet.</div>
              : <DataTable headers={["#","Achievement","Target","Measure","Owner"]} rows={project.keySuccesses.map((k,i) => [
                  <span style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#666" }}>{i+1}</span>,
                  k.achievement,
                  <span style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:GOLD }}>{k.target}</span>,
                  k.measure||"--", k.owner
                ])} />
            }
          </div>
        )}

        {activeTab === "stakeholders" && (
          <div>
            <SectionTitle>Stakeholders</SectionTitle>
            {project.stakeholders.length === 0
              ? <div style={{ color:"#555", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No stakeholders defined yet.</div>
              : <DataTable headers={["#","Name","Department","Role","Involvement","Communication"]} rows={project.stakeholders.map((s,i) => [
                  <span style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#666" }}>{i+1}</span>,
                  s.name, s.department, s.role,
                  <span style={{ color:s.involvement==="High"?"#f87171":s.involvement==="Medium"?GOLD:"#6b7280" }}>{s.involvement}</span>,
                  s.communication
                ])} />
            }
          </div>
        )}

        {activeTab === "meetings" && (
          <div>
            {upcomingMeetings.length > 0 && (
              <div>
                <SectionTitle>Upcoming Meetings</SectionTitle>
                <div style={{ display:"flex", flexDirection:"column", gap:10, marginBottom:28 }}>
                  {upcomingMeetings.map((m,i) => {
                    const urg = getUrg(m.date);
                    return (
                      <div key={i} style={{ background:urg==="urgent"?"rgba(220,38,38,0.07)":urg==="soon"?"rgba(217,119,6,0.07)":CARD, border:"1px solid "+(urg==="urgent"?"#dc2626":urg==="soon"?"#d97706":BORDER), borderRadius:8, padding:"18px 24px" }}>
                        <div style={{ display:"flex", alignItems:"center", gap:16, flexWrap:"wrap" }}>
                          <div style={{ minWidth:130, flexShrink:0 }}>
                            <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:urg==="urgent"?"#f87171":urg==="soon"?GOLD:"#888" }}>{fmtDate(m.date)}</div>
                            <div style={{ marginTop:4, display:"inline-block", fontFamily:"'DM Mono', monospace", fontSize:10, padding:"2px 8px", borderRadius:3, background:urg==="urgent"?"#dc2626":urg==="soon"?"#d97706":"#2a2a2a", color:urg!=="normal"?"#fff":"#666", fontWeight:700 }}>{daysUntil(m.date)}</div>
                          </div>
                          <div style={{ flex:1, minWidth:0 }}>
                            <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:15, fontWeight:600, color:"#eee", marginBottom:4, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{m.title}</div>
                            <div style={{ fontSize:13, color:"#888", fontFamily:"'DM Mono', monospace" }}>&#128101; {m.attendees}</div>
                            {m.notes && <div style={{ fontSize:14, color:"#aaa", marginTop:6 }}>{m.notes}</div>}
                          </div>
                          {urg!=="normal" && <div style={{ fontFamily:"'DM Mono', monospace", fontSize:10, color:urg==="urgent"?"#f87171":GOLD, border:"1px solid "+(urg==="urgent"?"#f87171":GOLD), padding:"4px 10px", borderRadius:4, whiteSpace:"nowrap", flexShrink:0 }}>{urg==="urgent"?"⚠ Urgent":"⏰ Soon"}</div>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
            {pastMeetings.length > 0 && (
              <div>
                <SectionTitle>Past Meetings</SectionTitle>
                <div style={{ display:"flex", flexDirection:"column", gap:8 }}>
                  {pastMeetings.map((m,i) => (
                    <div key={i} style={{ background:"#191919", border:"1px solid "+BORDER, borderRadius:8, padding:"14px 24px", opacity:0.7 }}>
                      <div style={{ display:"flex", alignItems:"center", gap:16, flexWrap:"wrap" }}>
                        <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#555", minWidth:130, flexShrink:0 }}>{fmtDate(m.date)}</div>
                        <div style={{ flex:1, minWidth:0 }}>
                          <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:14, color:"#888", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{m.title}</div>
                          <div style={{ fontSize:12, color:"#555", fontFamily:"'DM Mono', monospace" }}>&#128101; {m.attendees}</div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
            {(project.meetings||[]).length === 0 && <div style={{ color:"#555", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No meetings scheduled.</div>}
          </div>
        )}

        {activeTab === "dependencies" && (
          <div>
            {[{label:"Internal Dependencies",key:"internal"},{label:"External Dependencies",key:"external"},{label:"Key Risks",key:"risks"}].map(({label,key}) => (
              <div key={key}>
                <SectionTitle>{label}</SectionTitle>
                <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, overflow:"hidden" }}>
                  {(project.dependencies[key]||[]).filter(Boolean).length === 0
                    ? <div style={{ padding:"14px 20px", color:"#444", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:12 }}>None listed.</div>
                    : (project.dependencies[key]||[]).filter(Boolean).map((item,i,arr) => (
                      <div key={i} style={{ display:"grid", gridTemplateColumns:"50px 1fr", borderBottom:i<arr.length-1?"1px solid "+BORDER:"none" }}>
                        <div style={{ padding:"12px 16px", background:"#252525", fontFamily:"'DM Mono', monospace", fontSize:12, color:"#666", borderRight:"1px solid "+BORDER, display:"flex", alignItems:"center", justifyContent:"center" }}>{i+1}</div>
                        <div style={{ padding:"12px 20px", fontSize:15, color:"#ccc" }}>{item}</div>
                      </div>
                    ))
                  }
                </div>
              </div>
            ))}
          </div>
        )}

        {activeTab === "budget" && (
          <div>
            <SectionTitle>Project Budget</SectionTitle>
            <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, overflow:"hidden" }}>
              <div style={{ display:"grid", gridTemplateColumns:"50px 1fr 200px 150px 150px", borderBottom:"1px solid "+BORDER }}>
                {["#","Description of Cost","","Estimated Cost","Actual Cost"].map((h,i) => (
                  <div key={i} style={{ padding:"10px 16px", background:"#252525", fontFamily:"'DM Mono', monospace", fontSize:11, color:"#888", borderRight:i<4?"1px solid "+BORDER:"none", letterSpacing:"0.06em" }}>{h}</div>
                ))}
              </div>
              {Array.from({length:5}).map((_,i) => (
                <div key={i} style={{ display:"grid", gridTemplateColumns:"50px 1fr 200px 150px 150px", borderBottom:"1px solid "+BORDER }}>
                  <div style={{ padding:"12px 16px", fontFamily:"'DM Mono', monospace", fontSize:12, color:"#555", borderRight:"1px solid "+BORDER }}>{i+1}</div>
                  <div style={{ padding:"12px 16px", color:"#444", borderRight:"1px solid "+BORDER }}>--</div>
                  <div style={{ padding:"12px 16px", borderRight:"1px solid "+BORDER }} />
                  <div style={{ padding:"12px 16px", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:13, borderRight:"1px solid "+BORDER }}>$0.00</div>
                  <div style={{ padding:"12px 16px", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:13 }}>$0.00</div>
                </div>
              ))}
              <div style={{ display:"grid", gridTemplateColumns:"50px 1fr 200px 150px 150px", background:"#252525" }}>
                <div style={{ gridColumn:"1/4", padding:"12px 16px", fontFamily:"'DM Mono', monospace", fontSize:12, color:GOLD, fontWeight:700, borderRight:"1px solid "+BORDER }}>TOTAL</div>
                <div style={{ padding:"12px 16px", fontFamily:"'DM Mono', monospace", fontSize:13, color:GOLD, borderRight:"1px solid "+BORDER }}>$0.00</div>
                <div style={{ padding:"12px 16px", fontFamily:"'DM Mono', monospace", fontSize:13, color:GOLD }}>$0.00</div>
              </div>
            </div>
          </div>
        )}

        {activeTab === "updates" && (
          <div>
            <SectionTitle>Status Updates</SectionTitle>
            {project.statusUpdates.length === 0
              ? <div style={{ color:"#555", fontStyle:"italic", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No updates yet.</div>
              : <div style={{ display:"flex", flexDirection:"column", gap:12 }}>
                  {project.statusUpdates.map((u,i) => (
                    <div key={i} style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, padding:"18px 24px", display:"grid", gridTemplateColumns:"120px 1fr", gap:20 }}>
                      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:13, color:GOLD }}>{u.date}</div>
                      <div style={{ fontSize:15, color:"#ccc", lineHeight:1.6 }}>{u.notes}</div>
                    </div>
                  ))}
                </div>
            }
          </div>
        )}

      </div>
    </div>
  );
}

// ── My View ──────────────────────────────────────────────────────────────────
function MyView({ name, projects, onSelectProject }) {
  const today = new Date(); today.setHours(0,0,0,0);
  const match = nameMatcher(name);

  const myProjects = projects.filter(p => match(p.owner));
  const myPhases   = projects.flatMap(p => (p.phases||[]).filter(ph => match(ph.owner)).map(ph => ({ ...ph, projectName:p.name, project:p })));
  const myMeetings = projects.flatMap(p =>
    (p.meetings||[]).filter(m => (m.attendees||"").split(",").some(a => match(a.trim()))).map(m => ({ ...m, projectName:p.name, project:p }))
  ).sort((a,b) => new Date(a.date)-new Date(b.date));

  const upcomingMeetings = myMeetings.filter(m => new Date(m.date) >= today);
  const pastMeetings     = myMeetings.filter(m => new Date(m.date) < today);
  const myUpdates = projects.filter(p => match(p.owner) && p.statusUpdates && p.statusUpdates.length > 0)
    .map(p => ({ project:p, latest:p.statusUpdates[p.statusUpdates.length-1] }));
  const myStakeholderProjects = projects.flatMap(p =>
    (p.stakeholders||[]).filter(s => match(s.name)).map(s => ({ project:p, role:s.role, involvement:s.involvement, communication:s.communication }))
  ).filter(({ project:p }) => !match(p.owner));

  const getUrg = d => { const diff=(new Date(d)-today)/86400000; return diff<=3?"urgent":diff<=7?"soon":"normal"; };
  const fmtDate = d => new Date(d).toLocaleDateString("en-US",{weekday:"short",month:"short",day:"numeric"});
  const daysUntil = d => { const diff=Math.ceil((new Date(d)-today)/86400000); if(diff===0)return"Today"; if(diff===1)return"Tomorrow"; if(diff<0)return Math.abs(diff)+"d ago"; return"In "+diff+"d"; };
  const urgentCount = upcomingMeetings.filter(m => getUrg(m.date) !== "normal").length;

  const hasAnything = myProjects.length || myPhases.length || upcomingMeetings.length || myUpdates.length || myStakeholderProjects.length;

  if (!hasAnything) return (
    <div style={{ padding:"80px 32px", textAlign:"center" }}>
      <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:22, color:"#444", marginBottom:8 }}>No results for &quot;{name}&quot;</div>
      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#333" }}>Try a different name or partial match</div>
    </div>
  );

  return (
    <div style={{ padding:"28px 32px", maxWidth:1100 }}>
      <div style={{ marginBottom:28 }}>
        <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:26, fontWeight:700, color:"#fff" }}>
          Hi, <span style={{ color:GOLD }}>{name}</span>
        </div>
        <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555", marginTop:4, letterSpacing:"0.08em" }}>
          HERE&apos;S WHAT&apos;S ON YOUR PLATE
        </div>
      </div>

      <div style={{ display:"flex", gap:12, marginBottom:32, flexWrap:"wrap" }}>
        {[
          { label:"Projects Owned",    val:myProjects.length,            color:GOLD },
          { label:"Assigned Phases",   val:myPhases.length,              color:"#60a5fa" },
          { label:"Upcoming Meetings", val:upcomingMeetings.length,      color:"#a78bfa" },
          { label:"Stakeholder On",    val:myStakeholderProjects.length, color:"#34d399" },
          { label:"Pending Updates",   val:myUpdates.length,             color:"#f472b6" },
        ].map(({ label, val, color }) => (
          <div key={label} style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:10, padding:"14px 22px", display:"flex", flexDirection:"column", gap:4, minWidth:140 }}>
            <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:28, fontWeight:700, color }}>{val}</div>
            <div style={{ fontFamily:"'DM Mono', monospace", fontSize:10, color:"#555", letterSpacing:"0.08em", textTransform:"uppercase" }}>{label}</div>
          </div>
        ))}
      </div>

      {upcomingMeetings.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>
            Upcoming Meetings
            {urgentCount > 0 && <span style={{ background:"#dc2626", color:"#fff", borderRadius:"50%", width:16, height:16, fontSize:10, fontWeight:700, display:"inline-flex", alignItems:"center", justifyContent:"center", marginLeft:4 }}>{urgentCount}</span>}
          </SectionTitle>
          <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
            {upcomingMeetings.map((m,i) => {
              const urg = getUrg(m.date);
              return (
                <div key={i} style={{ background:urg==="urgent"?"rgba(220,38,38,0.07)":urg==="soon"?"rgba(217,119,6,0.07)":CARD, border:"1px solid "+(urg==="urgent"?"#dc2626":urg==="soon"?"#d97706":BORDER), borderRadius:8, padding:"16px 22px" }}>
                  <div style={{ display:"flex", alignItems:"center", gap:16, flexWrap:"wrap" }}>
                    <div style={{ minWidth:110, flexShrink:0 }}>
                      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:urg!=="normal"?(urg==="urgent"?"#f87171":GOLD):"#777" }}>{fmtDate(m.date)}</div>
                      <div style={{ marginTop:4, display:"inline-block", fontFamily:"'DM Mono', monospace", fontSize:10, padding:"2px 7px", borderRadius:3, fontWeight:700, background:urg==="urgent"?"#dc2626":urg==="soon"?"#d97706":"#2a2a2a", color:urg!=="normal"?"#fff":"#555" }}>{daysUntil(m.date)}</div>
                    </div>
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:14, fontWeight:600, color:"#eee", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{m.title}</div>
                      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#666", marginTop:2, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>&#128101; {m.attendees}</div>
                    </div>
                    <button onClick={() => onSelectProject(m.project)} style={{ background:"none", border:"1px solid "+BORDER, color:GOLD, borderRadius:5, padding:"5px 12px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer", whiteSpace:"nowrap", flexShrink:0 }}>
                      &rarr; {m.projectName}
                    </button>
                    {urg !== "normal" && (
                      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:10, color:urg==="urgent"?"#f87171":GOLD, border:"1px solid "+(urg==="urgent"?"#f87171":GOLD), padding:"3px 9px", borderRadius:4, whiteSpace:"nowrap", flexShrink:0 }}>
                        {urg === "urgent" ? "⚠ Urgent" : "⏰ Soon"}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {myProjects.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>Projects I Own</SectionTitle>
          <div style={{ display:"grid", gridTemplateColumns:"repeat(auto-fill, minmax(300px, 1fr))", gap:12 }}>
            {myProjects.map(p => (
              <div key={p.id} onClick={() => onSelectProject(p)} style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:10, padding:"18px 20px", cursor:"pointer", borderLeft:"4px solid "+(GROUP_COLORS[p.group]||GOLD) }}
                onMouseEnter={e => e.currentTarget.style.borderColor=GOLD}
                onMouseLeave={e => e.currentTarget.style.borderColor=BORDER}>
                <div style={{ display:"flex", justifyContent:"space-between", alignItems:"flex-start", marginBottom:8 }}>
                  <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:15, fontWeight:600, color:"#eee", flex:1, marginRight:10, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{p.name}</div>
                  <StatusBadge status={p.status} small />
                </div>
                <div style={{ fontFamily:"'Crimson Pro', serif", fontSize:13, color:"#777", marginBottom:10, lineHeight:1.4, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{p.description}</div>
                <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center" }}>
                  <PriorityBadge priority={p.priority} />
                  <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:GOLD }}>{p.deadline}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {myPhases.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>Phases Assigned to Me</SectionTitle>
          <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:10, overflow:"hidden" }}>
            <table style={{ width:"100%", borderCollapse:"collapse" }}>
              <thead>
                <tr style={{ borderBottom:"1px solid "+BORDER }}>
                  {["Project","Timeline","Checkpoint","Deliverable","Status"].map((h,i) => (
                    <th key={i} style={{ textAlign:"left", padding:"9px 14px", background:"#252525", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:10, letterSpacing:"0.1em", textTransform:"uppercase" }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {myPhases.map((ph,i) => (
                  <tr key={i} style={{ borderBottom:i<myPhases.length-1?"1px solid "+BORDER:"none", cursor:"pointer" }} onClick={() => onSelectProject(ph.project)}>
                    <td style={{ padding:"11px 14px", fontFamily:"'DM Mono', monospace", fontSize:13, color:GOLD, whiteSpace:"nowrap", maxWidth:160, overflow:"hidden", textOverflow:"ellipsis" }}>{ph.projectName}</td>
                    <td style={{ padding:"11px 14px", fontFamily:"'DM Mono', monospace", fontSize:11, color:"#888", whiteSpace:"nowrap" }}>{ph.timeline}</td>
                    <td style={{ padding:"11px 14px", fontSize:13, color:"#ccc", maxWidth:240, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{ph.checkpoint}</td>
                    <td style={{ padding:"11px 14px", fontSize:13, color:"#888", maxWidth:180, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{ph.deliverable||"--"}</td>
                    <td style={{ padding:"11px 14px" }}><StatusBadge status={ph.status} small /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {myUpdates.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>Status Updates -- Action Needed</SectionTitle>
          <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
            {myUpdates.map(({ project:p, latest },i) => (
              <div key={i} style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:8, padding:"16px 22px", display:"grid", gridTemplateColumns:"1fr auto", gap:16, alignItems:"center" }}>
                <div>
                  <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:14, fontWeight:600, color:"#eee", marginBottom:4, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{p.name}</div>
                  <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555", marginBottom:6 }}>{latest.date}</div>
                  <div style={{ fontFamily:"'Crimson Pro', serif", fontSize:14, color:"#aaa", lineHeight:1.5 }}>{latest.notes}</div>
                </div>
                <button onClick={() => onSelectProject(p)} style={{ background:"none", border:"1px solid "+GOLD, color:GOLD, borderRadius:6, padding:"7px 16px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer", whiteSpace:"nowrap" }}>View Project &rarr;</button>
              </div>
            ))}
          </div>
        </div>
      )}

      {myStakeholderProjects.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>Projects I&apos;m a Stakeholder On</SectionTitle>
          <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:10, overflow:"hidden" }}>
            <table style={{ width:"100%", borderCollapse:"collapse" }}>
              <thead>
                <tr style={{ borderBottom:"1px solid "+BORDER }}>
                  {["Project","Group","Status","My Role","Involvement","Check-in Frequency"].map((h,i) => (
                    <th key={i} style={{ textAlign:"left", padding:"9px 14px", background:"#252525", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:10, letterSpacing:"0.1em", textTransform:"uppercase" }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {myStakeholderProjects.map(({ project:p, role, involvement, communication },i) => (
                  <tr key={i} onClick={() => onSelectProject(p)} style={{ borderBottom:i<myStakeholderProjects.length-1?"1px solid "+BORDER:"none", cursor:"pointer" }}
                    onMouseEnter={e => Array.from(e.currentTarget.cells).forEach(c => c.style.background="rgba(207,184,124,0.05)")}
                    onMouseLeave={e => Array.from(e.currentTarget.cells).forEach(c => c.style.background="")}>
                    <td style={{ padding:"12px 14px", fontFamily:"'Times New Roman', Times, serif", fontSize:14, fontWeight:600, color:"#eee", borderLeft:"3px solid "+(GROUP_COLORS[p.group]||GOLD), maxWidth:180, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{p.name}</td>
                    <td style={{ padding:"12px 14px" }}><span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:GROUP_COLORS[p.group]||GOLD }}>{p.group}</span></td>
                    <td style={{ padding:"12px 14px" }}><StatusBadge status={p.status} small /></td>
                    <td style={{ padding:"12px 14px" }}><span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, fontWeight:600, padding:"3px 9px", borderRadius:4, background:role==="Contributor"?"rgba(96,165,250,0.15)":role==="Advisor"?"rgba(207,184,124,0.15)":"rgba(107,114,128,0.15)", color:role==="Contributor"?"#60a5fa":role==="Advisor"?GOLD:"#9ca3af" }}>{role}</span></td>
                    <td style={{ padding:"12px 14px", fontFamily:"'DM Mono', monospace", fontSize:11, fontWeight:600, color:involvement==="High"?"#f87171":involvement==="Medium"?GOLD:"#6b7280" }}>{involvement}</td>
                    <td style={{ padding:"12px 14px", fontFamily:"'DM Mono', monospace", fontSize:12, color:"#888" }}>{communication}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {pastMeetings.length > 0 && (
        <div style={{ marginBottom:32 }}>
          <SectionTitle>Past Meetings</SectionTitle>
          <div style={{ display:"flex", flexDirection:"column", gap:8 }}>
            {pastMeetings.slice(0,5).map((m,i) => (
              <div key={i} style={{ background:"#191919", border:"1px solid "+BORDER, borderRadius:8, padding:"12px 22px", opacity:0.65 }}>
                <div style={{ display:"flex", alignItems:"center", gap:16, flexWrap:"wrap" }}>
                  <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555", minWidth:110, flexShrink:0 }}>{fmtDate(m.date)}</div>
                  <div style={{ flex:1, minWidth:0, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                    <span style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:14, color:"#777" }}>{m.title}</span>
                    <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#444", marginLeft:10 }}>&#128101; {m.attendees}</span>
                  </div>
                  <button onClick={() => onSelectProject(m.project)} style={{ background:"none", border:"1px solid "+BORDER, color:"#555", borderRadius:5, padding:"4px 10px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer", flexShrink:0 }}>
                    &rarr; {m.projectName}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  const [selectedProject, setSelectedProject] = useState(null);
  const [search, setSearch]                   = useState("");
  const [filterStatus, setFilterStatus]       = useState("All");
  const [filterGroup, setFilterGroup]         = useState("All");
  const [mainTab, setMainTab]                 = useState("all");
  const [myNameInput, setMyNameInput]         = useState("");
  const [myNameActive, setMyNameActive]       = useState("");
  const [nameSuggestions, setNameSuggestions] = useState([]);
  const [projects, setProjects]               = useState([]);
  const [loading, setLoading]                 = useState(true);
  const [loadError, setLoadError]             = useState(null);

  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        setLoadError(null);
        const projectRows = await fetchCSV("Projects");
        const projectList = parseProjectsTab(projectRows);
        if (projectList.length === 0) throw new Error("Projects tab is empty or column headers are not matching.");
        const detailed = await Promise.all(projectList.map(async p => {
          try {
            const rows = await fetchCSV(p.name);
            const detail = parseProjectTab(rows);
            return {
              ...p, ...detail,
              overview: { ...detail.overview, owner:detail.overview.owner||p.owner, priority:detail.overview.priority||p.priority, status:detail.overview.status||p.status, timeline:detail.overview.timeline||p.timeline, deadline:detail.overview.deadline||p.deadline, budget:detail.overview.budget||p.budget },
            };
          } catch {
            return { ...p, overview:{objective:"",strategicPriority:"",successCriteria:"",owner:p.owner,priority:p.priority,status:p.status,timeline:p.timeline,deadline:p.deadline,budget:p.budget}, phases:[], keySuccesses:[], stakeholders:[], meetings:[], dependencies:{internal:[],external:[],risks:[]}, budget_items:[], statusUpdates:[] };
          }
        }));
        setProjects(detailed);
      } catch (err) {
        setLoadError(err.message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const livePeople = Array.from(new Set(projects.flatMap(p => {
    const names = [p.owner];
    (p.stakeholders||[]).forEach(s => names.push(s.name));
    (p.phases||[]).forEach(ph => names.push(ph.owner));
    (p.meetings||[]).forEach(m => (m.attendees||"").split(",").forEach(n => names.push(n.trim())));
    return names.filter(Boolean);
  }))).sort();

  const groups   = ["All", ...Array.from(new Set(projects.map(p => p.group)))];
  const statuses = ["All", ...Object.keys(STATUS_COLORS)];

  const filtered = projects.filter(p => {
    const s = search.toLowerCase();
    return (p.name.toLowerCase().includes(s) || p.description.toLowerCase().includes(s) || p.owner.toLowerCase().includes(s))
      && (filterStatus === "All" || p.status === filterStatus)
      && (filterGroup === "All" || p.group === filterGroup);
  });

  const groupedProjects = groups.filter(g => g !== "All").reduce((acc, g) => {
    acc[g] = filtered.filter(p => p.group === g);
    return acc;
  }, {});

  const handleNameInput = val => {
    setMyNameInput(val);
    setNameSuggestions(val.length >= 2 ? livePeople.filter(n => n.toLowerCase().includes(val.toLowerCase())).slice(0, 6) : []);
  };

  const handleNameSelect = name => { setMyNameActive(name); setMyNameInput(name); setNameSuggestions([]); setMainTab("mine"); };

  if (selectedProject) return <ProjectDetail project={selectedProject} onBack={() => setSelectedProject(null)} />;

  if (loading) return (
    <div style={{ minHeight:"100vh", background:DARK, display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", gap:16 }}>
      <div style={{ width:40, height:40, border:"3px solid "+BORDER, borderTop:"3px solid "+GOLD, borderRadius:"50%", animation:"spin 0.8s linear infinite" }} />
      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#555", letterSpacing:"0.1em" }}>LOADING FROM GOOGLE SHEETS...</div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );

  if (loadError) return (
    <div style={{ minHeight:"100vh", background:DARK, display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", gap:16, padding:32 }}>
      <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:22, color:"#f87171" }}>Could not load sheet</div>
      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#555", maxWidth:500, textAlign:"center", lineHeight:1.6 }}>{loadError}</div>
      <div style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#444", maxWidth:500, textAlign:"center", lineHeight:1.8 }}>
        Make sure your sheet is set to <span style={{ color:GOLD }}>Anyone with the link &rarr; Viewer</span> and published via File &rarr; Share &rarr; Publish to web.
      </div>
      <button onClick={() => window.location.reload()} style={{ marginTop:8, background:"none", border:"1px solid "+GOLD, color:GOLD, borderRadius:6, padding:"8px 20px", fontFamily:"'DM Mono', monospace", fontSize:12, cursor:"pointer" }}>Retry</button>
    </div>
  );

  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Crimson+Pro:ital,wght@0,400;0,600;1,400&family=DM+Mono:wght@400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #111; }
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #1a1a1a; }
        ::-webkit-scrollbar-thumb { background: #333; border-radius: 3px; }
        .project-row:hover td { background: rgba(207,184,124,0.05) !important; }
        .filter-btn:hover { border-color: #CFB87C !important; color: #CFB87C !important; }
        .name-suggestion:hover { background: rgba(207,184,124,0.1) !important; color: #CFB87C !important; }
      `}</style>

      <div style={{ minHeight:"100vh", background:DARK, color:"#e5e5e5" }}>
        <div style={{ background:BLACK, borderBottom:"1px solid "+BORDER, padding:"0 32px", position:"sticky", top:0, zIndex:10 }}>
          <div style={{ display:"flex", alignItems:"center", gap:20, padding:"16px 0" }}>
            <div style={{ display:"flex", alignItems:"center", gap:12 }}>
              <div style={{ width:32, height:32, borderRadius:6, background:GOLD, display:"flex", alignItems:"center", justifyContent:"center" }}>
                <span style={{ color:BLACK, fontWeight:900, fontFamily:"'Times New Roman', serif", fontSize:16 }}>V</span>
              </div>
              <div>
                <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:18, fontWeight:700, color:"#fff" }}>Vanderbilt Athletics</div>
                <div style={{ fontFamily:"'DM Mono', monospace", fontSize:10, color:"#666", letterSpacing:"0.1em", textTransform:"uppercase" }}>Project Tracker</div>
              </div>
            </div>
            <div style={{ display:"flex", gap:4, marginLeft:24, background:"#252525", borderRadius:8, padding:4 }}>
              {[["all","All Projects"],["mine","My View"]].map(([key,label]) => (
                <button key={key} onClick={() => setMainTab(key)} style={{ background:mainTab===key?(key==="mine"?GOLD:"#333"):"none", border:"none", color:mainTab===key?(key==="mine"?BLACK:"#fff"):"#666", borderRadius:5, padding:"6px 16px", fontFamily:"'DM Mono', monospace", fontSize:12, cursor:"pointer", fontWeight:mainTab===key?700:400 }}>
                  {label}
                </button>
              ))}
            </div>
            <div style={{ marginLeft:"auto" }}>
              {mainTab === "all" ? (
                <input placeholder="Search projects..." value={search} onChange={e => setSearch(e.target.value)}
                  style={{ background:"#252525", border:"1px solid "+BORDER, borderRadius:6, padding:"8px 14px", color:"#ccc", fontFamily:"'DM Mono', monospace", fontSize:12, outline:"none", width:220 }} />
              ) : (
                <div style={{ position:"relative" }}>
                  <input placeholder="Search your name..." value={myNameInput} onChange={e => handleNameInput(e.target.value)}
                    onKeyDown={e => { if (e.key === "Enter" && myNameInput) handleNameSelect(myNameInput); }}
                    style={{ background:myNameActive?"rgba(207,184,124,0.08)":"#252525", border:"1px solid "+(myNameActive?GOLD:BORDER), borderRadius:6, padding:"8px 14px", color:"#ccc", fontFamily:"'DM Mono', monospace", fontSize:12, outline:"none", width:240 }} />
                  {nameSuggestions.length > 0 && (
                    <div style={{ position:"absolute", top:"100%", left:0, right:0, background:"#1e1e1e", border:"1px solid "+BORDER, borderRadius:6, marginTop:4, zIndex:100, overflow:"hidden" }}>
                      {nameSuggestions.map(n => (
                        <div key={n} className="name-suggestion" onClick={() => handleNameSelect(n)}
                          style={{ padding:"9px 14px", cursor:"pointer", fontFamily:"'DM Mono', monospace", fontSize:12, color:"#aaa", borderBottom:"1px solid "+BORDER }}>{n}</div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
          {mainTab === "all" && (
            <div style={{ display:"flex", gap:8, paddingBottom:12, flexWrap:"wrap" }}>
              <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555", alignSelf:"center", marginRight:4 }}>FILTER:</span>
              {statuses.map(s => (
                <button key={s} className="filter-btn" onClick={() => setFilterStatus(s)} style={{ background:filterStatus===s?GOLD:"none", border:"1px solid "+(filterStatus===s?GOLD:BORDER), color:filterStatus===s?BLACK:"#777", borderRadius:4, padding:"4px 12px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer", fontWeight:filterStatus===s?700:400 }}>{s}</button>
              ))}
              <div style={{ width:1, background:BORDER, margin:"0 4px" }} />
              {groups.map(g => (
                <button key={g} className="filter-btn" onClick={() => setFilterGroup(g)} style={{ background:filterGroup===g?(GROUP_COLORS[g]||GOLD):"none", border:"1px solid "+(filterGroup===g?(GROUP_COLORS[g]||GOLD):BORDER), color:filterGroup===g?BLACK:"#777", borderRadius:4, padding:"4px 12px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer", fontWeight:filterGroup===g?700:400 }}>{g}</button>
              ))}
            </div>
          )}
          {mainTab === "mine" && <div style={{ height:12 }} />}
        </div>

        {mainTab === "mine" && (
          myNameActive
            ? <MyView name={myNameActive} projects={projects} onSelectProject={p => setSelectedProject(p)} />
            : (
              <div style={{ padding:"80px 32px", textAlign:"center" }}>
                <div style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:26, color:"#333", marginBottom:10 }}>Who are you?</div>
                <div style={{ fontFamily:"'DM Mono', monospace", fontSize:12, color:"#444", marginBottom:24 }}>Type your name in the search bar above to see your personalized view</div>
                <div style={{ display:"flex", flexWrap:"wrap", gap:8, justifyContent:"center", maxWidth:600, margin:"0 auto" }}>
                  {livePeople.slice(0,12).map(n => (
                    <button key={n} onClick={() => handleNameSelect(n)} style={{ background:CARD, border:"1px solid "+BORDER, color:"#777", borderRadius:20, padding:"6px 14px", fontFamily:"'DM Mono', monospace", fontSize:11, cursor:"pointer" }}
                      onMouseEnter={e => { e.currentTarget.style.borderColor=GOLD; e.currentTarget.style.color=GOLD; }}
                      onMouseLeave={e => { e.currentTarget.style.borderColor=BORDER; e.currentTarget.style.color="#777"; }}>{n}</button>
                  ))}
                </div>
              </div>
            )
        )}

        {mainTab === "all" && (
          <div style={{ padding:"28px 32px" }}>
            {Object.entries(groupedProjects).map(([group, gProjects]) => {
              if (gProjects.length === 0) return null;
              const groupColor = GROUP_COLORS[group] || GOLD;
              return (
                <div key={group} style={{ marginBottom:36 }}>
                  <div style={{ display:"flex", alignItems:"center", gap:10, marginBottom:10 }}>
                    <div style={{ width:12, height:12, borderRadius:"50%", background:groupColor }} />
                    <span style={{ fontFamily:"'Times New Roman', Times, serif", fontSize:16, fontWeight:700, color:groupColor }}>{group}</span>
                    <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555", background:"#252525", border:"1px solid "+BORDER, borderRadius:10, padding:"1px 8px" }}>{gProjects.length}</span>
                  </div>
                  <div style={{ background:CARD, border:"1px solid "+BORDER, borderRadius:10, overflowX:"auto" }}>
                    <table style={{ width:"100%", minWidth:1000, borderCollapse:"collapse", tableLayout:"fixed" }}>
                      <colgroup>
                        <col style={{ width:190 }} /><col style={{ width:220 }} /><col style={{ width:130 }} />
                        <col style={{ width:90 }} /><col style={{ width:140 }} /><col style={{ width:110 }} />
                        <col style={{ width:120 }} /><col style={{ width:90 }} />
                      </colgroup>
                      <thead>
                        <tr style={{ borderBottom:"1px solid "+BORDER }}>
                          {["Project Name","Description","Owner","Priority","Timeline","Status","Deadline","Budget"].map((h,i) => (
                            <th key={i} style={{ textAlign:"left", padding:"10px 16px", background:"#252525", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:10, letterSpacing:"0.1em", textTransform:"uppercase", fontWeight:500, borderLeft:i===0?"3px solid "+groupColor:"none" }}>{h}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {gProjects.map((project,ri) => (
                          <tr key={project.id} className="project-row" onClick={() => setSelectedProject(project)} style={{ borderBottom:ri<gProjects.length-1?"1px solid "+BORDER:"none", cursor:"pointer" }}>
                            <td style={{ padding:"13px 16px", fontFamily:"'Times New Roman', Times, serif", fontSize:14, fontWeight:600, color:"#eee", borderLeft:"3px solid "+groupColor, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.name}</td>
                            <td style={{ padding:"13px 16px", color:"#888", fontSize:13, fontFamily:"'Crimson Pro', serif", overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.description}</td>
                            <td style={{ padding:"13px 16px", color:"#aaa", fontFamily:"'DM Mono', monospace", fontSize:12, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.owner}</td>
                            <td style={{ padding:"13px 16px" }}><PriorityBadge priority={project.priority} /></td>
                            <td style={{ padding:"13px 16px", color:"#888", fontFamily:"'DM Mono', monospace", fontSize:11, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.timeline}</td>
                            <td style={{ padding:"13px 16px" }}><StatusBadge status={project.status} /></td>
                            <td style={{ padding:"13px 16px", color:GOLD, fontFamily:"'DM Mono', monospace", fontSize:12, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.deadline}</td>
                            <td style={{ padding:"13px 16px", color:"#666", fontFamily:"'DM Mono', monospace", fontSize:12, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{project.budget}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              );
            })}
            {filtered.length === 0 && (
              <div style={{ textAlign:"center", padding:"80px 0", color:"#444", fontFamily:"'DM Mono', monospace", fontSize:13 }}>No projects match your filters.</div>
            )}
            <div style={{ marginTop:8, padding:"16px 24px", background:CARD, border:"1px solid "+BORDER, borderRadius:10, display:"flex", gap:32, flexWrap:"wrap" }}>
              {Object.entries(STATUS_COLORS).map(([status,colors]) => {
                const count = projects.filter(p => p.status === status).length;
                if (!count) return null;
                return (
                  <div key={status} style={{ display:"flex", alignItems:"center", gap:8 }}>
                    <div style={{ width:8, height:8, borderRadius:"50%", background:colors.bg }} />
                    <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#666" }}>{status}</span>
                    <span style={{ fontFamily:"'DM Mono', monospace", fontSize:11, color:"#999", fontWeight:600 }}>{count}</span>
                  </div>
                );
              })}
              <div style={{ marginLeft:"auto", fontFamily:"'DM Mono', monospace", fontSize:11, color:"#555" }}>{projects.length} total projects</div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
