<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Vanderbilt Athletics — Project Tracker</title>
  <script src="https://unpkg.com/react@18/umd/react.production.min.js" crossorigin></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js" crossorigin></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Crimson+Pro:ital,wght@0,400;0,600;1,400&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #111; font-family: sans-serif; }
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: #1a1a1a; }
    ::-webkit-scrollbar-thumb { background: #333; border-radius: 3px; }
    .prow:hover td { background: rgba(207,184,124,0.05) !important; }
    .fbtn:hover { border-color: #CFB87C !important; color: #CFB87C !important; }
    .sugg:hover { background: rgba(207,184,124,0.1) !important; color: #CFB87C !important; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel">

const SCRIPT_URL = "https://script.google.com/macros/s/AKfycbyQefyFbFZCkjPbZmKgEMfvSZPykCzOaGr84mN-2Rqt2XjmwRRsXP3-3-AY-mj7tGfL/exec";

const { useState, useEffect } = React;

const GOLD   = "#CFB87C";
const BLACK  = "#1a1a1a";
const DARK   = "#111";
const CARD   = "#1e1e1e";
const BORDER = "#2e2e2e";

const STATUS_COLORS = {
  "On Track":    { bg:"#16a34a", text:"#fff" },
  "In Progress": { bg:"#d97706", text:"#fff" },
  "Not Started": { bg:"#6b7280", text:"#fff" },
  "Complete":    { bg:"#0ea5e9", text:"#fff" },
  "At Risk":     { bg:"#dc2626", text:"#fff" },
  "On Hold":     { bg:"#7c3aed", text:"#fff" },
};
const PRIORITY_COLORS = {
  "High":   { bg:"#dc2626", text:"#fff" },
  "Medium": { bg:"#d97706", text:"#fff" },
  "Low":    { bg:"#16a34a", text:"#fff" },
};
const FIXED_GROUP_COLORS = {
  "Executive Team":   "#CFB87C",
  "Operations":       "#60a5fa",
  "Compliance":       "#f472b6",
  "Roster & Finance": "#34d399",
};
function getGroupColor(group) {
  if (FIXED_GROUP_COLORS[group]) return FIXED_GROUP_COLORS[group];
  const colors = ["#a78bfa","#fb923c","#34d399","#f472b6","#60a5fa","#facc15"];
  let h = 0; for (let i=0;i<(group||"").length;i++) h=(group.charCodeAt(i)+((h<<5)-h));
  return colors[Math.abs(h)%colors.length];
}

function nameMatcher(query) {
  const q = query.trim().toLowerCase();
  const parts = q.split(/\s+/);
  return (str) => {
    if (!str) return false;
    const s = str.toLowerCase();
    if (s.includes(q)) return true;
    if (parts.length===1) return s.split(/[,\/]/).some(t=>t.trim().split(/\s+/)[0]===parts[0]);
    return false;
  };
}

function StatusBadge({ status, small }) {
  const c = STATUS_COLORS[status] || { bg:"#6b7280", text:"#fff" };
  return <span style={{background:c.bg,color:c.text,padding:small?"2px 8px":"3px 10px",borderRadius:4,fontSize:small?11:12,fontWeight:600,fontFamily:"'DM Mono',monospace",whiteSpace:"nowrap"}}>{status}</span>;
}
function PriorityBadge({ priority }) {
  const c = PRIORITY_COLORS[priority] || { bg:"#6b7280", text:"#fff" };
  return <span style={{background:c.bg,color:c.text,padding:"3px 10px",borderRadius:4,fontSize:12,fontWeight:600,fontFamily:"'DM Mono',monospace",whiteSpace:"nowrap"}}>{priority}</span>;
}
function SectionTitle({ children }) {
  return <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,letterSpacing:"0.15em",color:GOLD,textTransform:"uppercase",marginBottom:12,marginTop:24,display:"flex",alignItems:"center",gap:10}}><div style={{width:3,height:14,background:GOLD,borderRadius:2}}/>{children}</div>;
}
function EmptyMsg({ text }) {
  return <div style={{color:"#555",fontStyle:"italic",fontFamily:"'DM Mono',monospace",fontSize:13,padding:"16px 0"}}>{text}</div>;
}
function LoadingScreen() {
  return <div style={{minHeight:"100vh",background:DARK,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:20}}>
    <div style={{width:40,height:40,border:"3px solid #2e2e2e",borderTop:"3px solid "+GOLD,borderRadius:"50%",animation:"spin 0.8s linear infinite"}}/>
    <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:"#555",letterSpacing:"0.1em"}}>LOADING PROJECTS...</div>
  </div>;
}
function ErrorScreen({ message, onRetry }) {
  return <div style={{minHeight:"100vh",background:DARK,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:16,padding:32}}>
    <div style={{fontFamily:"'Times New Roman',serif",fontSize:22,color:"#dc2626"}}>Failed to load data</div>
    <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:"#666",maxWidth:500,textAlign:"center",lineHeight:1.8}}>{message}</div>
    <button onClick={onRetry} style={{background:"none",border:"1px solid "+GOLD,color:GOLD,borderRadius:6,padding:"8px 20px",fontFamily:"'DM Mono',monospace",fontSize:12,cursor:"pointer",marginTop:8}}>Try Again</button>
  </div>;
}

function ProjectDetail({ project, onBack }) {
  const [tab, setTab] = useState("overview");
  const TABS = ["overview","phases","successes","stakeholders","meetings","dependencies","budget","updates"];
  const today = new Date(); today.setHours(0,0,0,0);
  const gc = getGroupColor(project.group);
  const upcoming = (project.meetings||[]).filter(m=>{try{return new Date(m.date)>=today}catch{return false}}).sort((a,b)=>new Date(a.date)-new Date(b.date));
  const past = (project.meetings||[]).filter(m=>{try{return new Date(m.date)<today}catch{return false}}).sort((a,b)=>new Date(b.date)-new Date(a.date));
  const urg = d=>{try{const diff=(new Date(d)-today)/86400000;return diff<=3?"urgent":diff<=7?"soon":"normal"}catch{return"normal"}};
  const fmtD = d=>{try{return new Date(d).toLocaleDateString("en-US",{weekday:"short",month:"short",day:"numeric",year:"numeric"})}catch{return d}};
  const daysU = d=>{try{const diff=Math.ceil((new Date(d)-today)/86400000);return diff===0?"Today":diff===1?"Tomorrow":"In "+diff+" days"}catch{return""}};
  const urgCount = upcoming.filter(m=>urg(m.date)!=="normal").length;

  return <div style={{minHeight:"100vh",background:DARK,color:"#e5e5e5"}}>
    <div style={{background:BLACK,borderBottom:"1px solid "+BORDER,padding:"0 32px",position:"sticky",top:0,zIndex:10}}>
      <div style={{display:"flex",alignItems:"center",gap:16,padding:"14px 0"}}>
        <button onClick={onBack} style={{background:"none",border:"1px solid "+BORDER,color:"#aaa",cursor:"pointer",borderRadius:6,padding:"6px 14px",fontFamily:"'DM Mono',monospace",fontSize:12}}>&larr; Back</button>
        <div style={{width:1,height:20,background:BORDER}}/>
        <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:gc,letterSpacing:"0.1em"}}>{project.group}</div>
        <div style={{color:BORDER}}>/</div>
        <div style={{fontFamily:"'Times New Roman',serif",fontSize:18,color:"#fff",fontWeight:700,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",maxWidth:340}}>{project.name}</div>
        <div style={{marginLeft:"auto",display:"flex",gap:8}}><PriorityBadge priority={project.priority}/><StatusBadge status={project.status}/></div>
      </div>
      <div style={{display:"flex",borderTop:"1px solid "+BORDER}}>
        {TABS.map(t=><button key={t} onClick={()=>setTab(t)} style={{background:"none",border:"none",borderBottom:tab===t?"2px solid "+GOLD:"2px solid transparent",color:tab===t?GOLD:"#666",padding:"10px 18px",cursor:"pointer",fontFamily:"'DM Mono',monospace",fontSize:12,textTransform:"capitalize",display:"flex",alignItems:"center",gap:6}}>
          {t}{t==="meetings"&&urgCount>0&&<span style={{background:"#dc2626",color:"#fff",borderRadius:"50%",width:16,height:16,fontSize:10,fontWeight:700,display:"flex",alignItems:"center",justifyContent:"center"}}>{urgCount}</span>}
        </button>)}
      </div>
    </div>
    <div style={{padding:"32px",maxWidth:1100,margin:"0 auto"}}>

      {tab==="overview"&&<div>
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr 1fr",gap:16,marginBottom:28}}>
          {[{l:"Owner",v:project.owner},{l:"Timeline",v:project.timeline},{l:"Deadline",v:project.deadline},{l:"Budget",v:project.budget},{l:"Priority",v:<PriorityBadge priority={project.priority}/>},{l:"Status",v:<StatusBadge status={project.status}/>}].map((item,i)=><div key={i} style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,padding:"16px 20px"}}>
            <div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:"#666",letterSpacing:"0.1em",textTransform:"uppercase",marginBottom:6}}>{item.l}</div>
            <div style={{fontSize:15,color:"#ddd"}}>{item.v}</div>
          </div>)}
        </div>
        <SectionTitle>Overview</SectionTitle>
        <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,overflow:"hidden"}}>
          {[["Objective","objective"],["Strategic Priority","strategicPriority"],["Success Criteria","successCriteria"]].map(([label,key],i,arr)=><div key={key} style={{display:"grid",gridTemplateColumns:"200px 1fr",borderBottom:i<arr.length-1?"1px solid "+BORDER:"none"}}>
            <div style={{padding:"14px 20px",background:"#252525",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#888",borderRight:"1px solid "+BORDER}}>{label}</div>
            <div style={{padding:"14px 20px",fontSize:15,color:"#ccc",lineHeight:1.6}}>{(project.overview||{})[key]||<span style={{color:"#444",fontStyle:"italic"}}>--</span>}</div>
          </div>)}
        </div>
      </div>}

      {tab==="phases"&&<div><SectionTitle>Project Phases</SectionTitle>
        {!(project.phases||[]).length?<EmptyMsg text="No phases defined yet."/>:<div style={{overflowX:"auto"}}>
          <table style={{width:"100%",borderCollapse:"collapse"}}>
            <thead><tr>{["Timeline","Checkpoint","Deliverable","Owner","Status"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"10px 14px",background:"#252525",color:"#999",fontFamily:"'DM Mono',monospace",fontSize:11,letterSpacing:"0.08em",textTransform:"uppercase",borderBottom:"1px solid "+BORDER,whiteSpace:"nowrap"}}>{h}</th>)}</tr></thead>
            <tbody>{(project.phases||[]).map((ph,i)=><tr key={i} style={{borderBottom:"1px solid "+BORDER}}>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:GOLD,verticalAlign:"top",whiteSpace:"nowrap"}}>{ph.timeline}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#ccc",verticalAlign:"top",lineHeight:1.6}}>{ph.checkpoint}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#aaa",verticalAlign:"top",lineHeight:1.6}}>{ph.deliverable||"--"}</td>
              <td style={{padding:"12px 14px",fontSize:13,color:"#bbb",verticalAlign:"top",whiteSpace:"nowrap"}}>{ph.owner}</td>
              <td style={{padding:"12px 14px",verticalAlign:"top"}}><StatusBadge status={ph.status} small/></td>
            </tr>)}</tbody>
          </table>
        </div>}
      </div>}

      {tab==="successes"&&<div><SectionTitle>Key Successes</SectionTitle>
        {!(project.keySuccesses||[]).length?<EmptyMsg text="No key successes defined yet."/>:<div style={{overflowX:"auto"}}>
          <table style={{width:"100%",borderCollapse:"collapse"}}>
            <thead><tr>{["#","Achievement","Target","Measure","Owner"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"10px 14px",background:"#252525",color:"#999",fontFamily:"'DM Mono',monospace",fontSize:11,letterSpacing:"0.08em",textTransform:"uppercase",borderBottom:"1px solid "+BORDER,whiteSpace:"nowrap"}}>{h}</th>)}</tr></thead>
            <tbody>{(project.keySuccesses||[]).map((k,i)=><tr key={i} style={{borderBottom:"1px solid "+BORDER}}>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#555",verticalAlign:"top"}}>{i+1}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#ccc",verticalAlign:"top",lineHeight:1.6}}>{k.achievement}</td>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:GOLD,verticalAlign:"top",whiteSpace:"nowrap"}}>{k.target}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#aaa",verticalAlign:"top"}}>{k.measure||"--"}</td>
              <td style={{padding:"12px 14px",fontSize:13,color:"#bbb",verticalAlign:"top"}}>{k.owner}</td>
            </tr>)}</tbody>
          </table>
        </div>}
      </div>}

      {tab==="stakeholders"&&<div><SectionTitle>Stakeholders</SectionTitle>
        {!(project.stakeholders||[]).length?<EmptyMsg text="No stakeholders defined yet."/>:<div style={{overflowX:"auto"}}>
          <table style={{width:"100%",borderCollapse:"collapse"}}>
            <thead><tr>{["#","Name","Department","Role","Involvement","Communication"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"10px 14px",background:"#252525",color:"#999",fontFamily:"'DM Mono',monospace",fontSize:11,letterSpacing:"0.08em",textTransform:"uppercase",borderBottom:"1px solid "+BORDER,whiteSpace:"nowrap"}}>{h}</th>)}</tr></thead>
            <tbody>{(project.stakeholders||[]).map((s,i)=><tr key={i} style={{borderBottom:"1px solid "+BORDER}}>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#555",verticalAlign:"top"}}>{i+1}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#ccc",verticalAlign:"top",lineHeight:1.6}}>{s.name}</td>
              <td style={{padding:"12px 14px",fontSize:14,color:"#aaa",verticalAlign:"top"}}>{s.department}</td>
              <td style={{padding:"12px 14px",verticalAlign:"top"}}><span style={{fontFamily:"'DM Mono',monospace",fontSize:11,fontWeight:600,padding:"3px 9px",borderRadius:4,background:s.role==="Contributor"?"rgba(96,165,250,0.15)":s.role==="Advisor"?"rgba(207,184,124,0.15)":"rgba(107,114,128,0.15)",color:s.role==="Contributor"?"#60a5fa":s.role==="Advisor"?GOLD:"#9ca3af",whiteSpace:"nowrap"}}>{s.role}</span></td>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,fontWeight:600,color:s.involvement==="High"?"#f87171":s.involvement==="Medium"?GOLD:"#6b7280",verticalAlign:"top"}}>{s.involvement}</td>
              <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#888",verticalAlign:"top"}}>{s.communication}</td>
            </tr>)}</tbody>
          </table>
        </div>}
      </div>}

      {tab==="meetings"&&<div>
        {upcoming.length>0&&<div><SectionTitle>Upcoming Meetings</SectionTitle>
          <div style={{display:"flex",flexDirection:"column",gap:10,marginBottom:28}}>
            {upcoming.map((m,i)=>{const u=urg(m.date);return<div key={i} style={{background:u==="urgent"?"rgba(220,38,38,0.07)":u==="soon"?"rgba(217,119,6,0.07)":CARD,border:"1px solid "+(u==="urgent"?"#dc2626":u==="soon"?"#d97706":BORDER),borderRadius:8,padding:"18px 24px"}}>
              <div style={{display:"flex",alignItems:"flex-start",gap:16,flexWrap:"wrap"}}>
                <div style={{minWidth:130,flexShrink:0}}>
                  <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:u==="urgent"?"#f87171":u==="soon"?GOLD:"#888"}}>{fmtD(m.date)}</div>
                  <div style={{marginTop:4,display:"inline-block",fontFamily:"'DM Mono',monospace",fontSize:10,padding:"2px 8px",borderRadius:3,background:u==="urgent"?"#dc2626":u==="soon"?"#d97706":"#2a2a2a",color:u!=="normal"?"#fff":"#666",fontWeight:700}}>{daysU(m.date)}</div>
                </div>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{fontFamily:"'Times New Roman',serif",fontSize:15,fontWeight:600,color:"#eee",marginBottom:4}}>{m.title}</div>
                  <div style={{fontSize:13,color:"#888",fontFamily:"'DM Mono',monospace"}}>&#128101; {m.attendees}</div>
                  {m.notes&&<div style={{fontSize:14,color:"#aaa",marginTop:6,lineHeight:1.5}}>{m.notes}</div>}
                </div>
                {u!=="normal"&&<div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:u==="urgent"?"#f87171":GOLD,border:"1px solid "+(u==="urgent"?"#f87171":GOLD),padding:"4px 10px",borderRadius:4,whiteSpace:"nowrap",flexShrink:0}}>{u==="urgent"?"! Urgent":"Soon"}</div>}
              </div>
            </div>;})}
          </div>
        </div>}
        {past.length>0&&<div><SectionTitle>Past Meetings</SectionTitle>
          <div style={{display:"flex",flexDirection:"column",gap:8}}>
            {past.map((m,i)=><div key={i} style={{background:"#191919",border:"1px solid "+BORDER,borderRadius:8,padding:"14px 24px",opacity:0.7}}>
              <div style={{display:"flex",alignItems:"center",gap:16,flexWrap:"wrap"}}>
                <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:"#555",minWidth:130,flexShrink:0}}>{fmtD(m.date)}</div>
                <div style={{flex:1}}><div style={{fontFamily:"'Times New Roman',serif",fontSize:14,color:"#888"}}>{m.title}</div><div style={{fontSize:12,color:"#555",fontFamily:"'DM Mono',monospace"}}>&#128101; {m.attendees}</div></div>
              </div>
            </div>)}
          </div>
        </div>}
        {!(project.meetings||[]).length&&<EmptyMsg text="No meetings scheduled."/>}
      </div>}

      {tab==="dependencies"&&<div>
        {[{label:"Internal Dependencies",key:"internal"},{label:"External Dependencies",key:"external"},{label:"Key Risks",key:"risks"}].map(({label,key})=><div key={key}>
          <SectionTitle>{label}</SectionTitle>
          <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,overflow:"hidden"}}>
            {!((project.dependencies||{})[key]||[]).filter(Boolean).length
              ?<div style={{padding:"14px 20px",color:"#444",fontStyle:"italic",fontFamily:"'DM Mono',monospace",fontSize:12}}>None listed.</div>
              :((project.dependencies||{})[key]||[]).filter(Boolean).map((item,i,arr)=><div key={i} style={{display:"grid",gridTemplateColumns:"50px 1fr",borderBottom:i<arr.length-1?"1px solid "+BORDER:"none"}}>
                <div style={{padding:"12px 16px",background:"#252525",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#666",borderRight:"1px solid "+BORDER,display:"flex",alignItems:"center",justifyContent:"center"}}>{i+1}</div>
                <div style={{padding:"12px 20px",fontSize:15,color:"#ccc",lineHeight:1.6}}>{item}</div>
              </div>)}
          </div>
        </div>)}
      </div>}

      {tab==="budget"&&<div><SectionTitle>Project Budget</SectionTitle>
        <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,overflow:"hidden"}}>
          <div style={{display:"grid",gridTemplateColumns:"50px 1fr 200px 150px 150px",borderBottom:"1px solid "+BORDER}}>
            {["#","Description","Notes","Estimated","Actual"].map((h,i)=><div key={i} style={{padding:"10px 16px",background:"#252525",fontFamily:"'DM Mono',monospace",fontSize:11,color:"#888",borderRight:i<4?"1px solid "+BORDER:"none"}}>{h}</div>)}
          </div>
          {Array.from({length:5}).map((_,i)=><div key={i} style={{display:"grid",gridTemplateColumns:"50px 1fr 200px 150px 150px",borderBottom:"1px solid "+BORDER}}>
            <div style={{padding:"12px 16px",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#555",borderRight:"1px solid "+BORDER}}>{i+1}</div>
            <div style={{padding:"12px 16px",color:"#444",borderRight:"1px solid "+BORDER}}>--</div>
            <div style={{padding:"12px 16px",borderRight:"1px solid "+BORDER}}/>
            <div style={{padding:"12px 16px",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:13,borderRight:"1px solid "+BORDER}}>$0.00</div>
            <div style={{padding:"12px 16px",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:13}}>$0.00</div>
          </div>)}
          <div style={{display:"grid",gridTemplateColumns:"50px 1fr 200px 150px 150px",background:"#252525"}}>
            <div style={{gridColumn:"1/4",padding:"12px 16px",fontFamily:"'DM Mono',monospace",fontSize:12,color:GOLD,fontWeight:700,borderRight:"1px solid "+BORDER}}>TOTAL</div>
            <div style={{padding:"12px 16px",fontFamily:"'DM Mono',monospace",fontSize:13,color:GOLD,borderRight:"1px solid "+BORDER}}>$0.00</div>
            <div style={{padding:"12px 16px",fontFamily:"'DM Mono',monospace",fontSize:13,color:GOLD}}>$0.00</div>
          </div>
        </div>
      </div>}

      {tab==="updates"&&<div><SectionTitle>Status Updates</SectionTitle>
        {!(project.statusUpdates||[]).length?<EmptyMsg text="No updates yet."/>:
          <div style={{display:"flex",flexDirection:"column",gap:12}}>
            {(project.statusUpdates||[]).map((u,i)=><div key={i} style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,padding:"18px 24px",display:"grid",gridTemplateColumns:"130px 1fr",gap:20}}>
              <div style={{fontFamily:"'DM Mono',monospace",fontSize:13,color:GOLD}}>{u.date}</div>
              <div style={{fontSize:15,color:"#ccc",lineHeight:1.6}}>{u.notes}</div>
            </div>)}
          </div>}
      </div>}

    </div>
  </div>;
}

function MyView({ name, projects, onSelect }) {
  const today = new Date(); today.setHours(0,0,0,0);
  const match = nameMatcher(name);
  const myProjects = projects.filter(p=>match(p.owner));
  const myPhases = projects.flatMap(p=>(p.phases||[]).filter(ph=>match(ph.owner)).map(ph=>({...ph,projectName:p.name,project:p})));
  const allMtgs = projects.flatMap(p=>(p.meetings||[]).filter(m=>(m.attendees||"").split(",").some(a=>match(a.trim()))).map(m=>({...m,projectName:p.name,project:p}))).sort((a,b)=>new Date(a.date)-new Date(b.date));
  const upcoming = allMtgs.filter(m=>{try{return new Date(m.date)>=today}catch{return false}});
  const past = allMtgs.filter(m=>{try{return new Date(m.date)<today}catch{return false}});
  const myUpdates = projects.filter(p=>match(p.owner)&&(p.statusUpdates||[]).length>0).map(p=>({project:p,latest:p.statusUpdates[p.statusUpdates.length-1]}));
  const stakeProjects = projects.flatMap(p=>(p.stakeholders||[]).filter(s=>match(s.name)).map(s=>({project:p,role:s.role,involvement:s.involvement,communication:s.communication}))).filter(({project:p})=>!match(p.owner));
  const urg = d=>{try{const diff=(new Date(d)-today)/86400000;return diff<=3?"urgent":diff<=7?"soon":"normal"}catch{return"normal"}};
  const fmtD = d=>{try{return new Date(d).toLocaleDateString("en-US",{weekday:"short",month:"short",day:"numeric"})}catch{return d}};
  const daysU = d=>{try{const diff=Math.ceil((new Date(d)-today)/86400000);if(diff===0)return"Today";if(diff===1)return"Tomorrow";if(diff<0)return Math.abs(diff)+"d ago";return"In "+diff+"d"}catch{return""}};
  const urgCount = upcoming.filter(m=>urg(m.date)!=="normal").length;
  const hasAny = myProjects.length||myPhases.length||upcoming.length||myUpdates.length||stakeProjects.length;

  if (!hasAny) return <div style={{padding:"80px 32px",textAlign:"center"}}>
    <div style={{fontFamily:"'Times New Roman',serif",fontSize:22,color:"#444",marginBottom:8}}>No results for "{name}"</div>
    <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:"#333"}}>Try a different name or partial match</div>
  </div>;

  return <div style={{padding:"28px 32px",maxWidth:1100}}>
    <div style={{marginBottom:28}}>
      <div style={{fontFamily:"'Times New Roman',serif",fontSize:26,fontWeight:700,color:"#fff"}}>Hi, <span style={{color:GOLD}}>{name}</span></div>
      <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555",marginTop:4,letterSpacing:"0.08em"}}>HERE'S WHAT'S ON YOUR PLATE</div>
    </div>
    <div style={{display:"flex",gap:12,marginBottom:32,flexWrap:"wrap"}}>
      {[{l:"Projects Owned",v:myProjects.length,c:GOLD},{l:"Assigned Phases",v:myPhases.length,c:"#60a5fa"},{l:"Upcoming Meetings",v:upcoming.length,c:"#a78bfa"},{l:"Stakeholder On",v:stakeProjects.length,c:"#34d399"},{l:"Pending Updates",v:myUpdates.length,c:"#f472b6"}].map(({l,v,c})=><div key={l} style={{background:CARD,border:"1px solid "+BORDER,borderRadius:10,padding:"14px 22px",minWidth:140}}>
        <div style={{fontFamily:"'Times New Roman',serif",fontSize:28,fontWeight:700,color:c}}>{v}</div>
        <div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:"#555",letterSpacing:"0.08em",textTransform:"uppercase"}}>{l}</div>
      </div>)}
    </div>

    {upcoming.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Upcoming Meetings {urgCount>0&&<span style={{background:"#dc2626",color:"#fff",borderRadius:"50%",width:16,height:16,fontSize:10,fontWeight:700,display:"inline-flex",alignItems:"center",justifyContent:"center",marginLeft:4}}>{urgCount}</span>}</SectionTitle>
      <div style={{display:"flex",flexDirection:"column",gap:10}}>
        {upcoming.map((m,i)=>{const u=urg(m.date);return<div key={i} style={{background:u==="urgent"?"rgba(220,38,38,0.07)":u==="soon"?"rgba(217,119,6,0.07)":CARD,border:"1px solid "+(u==="urgent"?"#dc2626":u==="soon"?"#d97706":BORDER),borderRadius:8,padding:"16px 22px"}}>
          <div style={{display:"flex",alignItems:"center",gap:16,flexWrap:"wrap"}}>
            <div style={{minWidth:110,flexShrink:0}}>
              <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:u!=="normal"?(u==="urgent"?"#f87171":GOLD):"#777"}}>{fmtD(m.date)}</div>
              <div style={{marginTop:4,display:"inline-block",fontFamily:"'DM Mono',monospace",fontSize:10,padding:"2px 7px",borderRadius:3,fontWeight:700,background:u==="urgent"?"#dc2626":u==="soon"?"#d97706":"#2a2a2a",color:u!=="normal"?"#fff":"#555"}}>{daysU(m.date)}</div>
            </div>
            <div style={{flex:1,minWidth:0}}>
              <div style={{fontFamily:"'Times New Roman',serif",fontSize:14,fontWeight:600,color:"#eee",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{m.title}</div>
              <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#666",marginTop:2}}>&#128101; {m.attendees}</div>
            </div>
            <button onClick={()=>onSelect(m.project)} style={{background:"none",border:"1px solid "+BORDER,color:GOLD,borderRadius:5,padding:"5px 12px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",whiteSpace:"nowrap",flexShrink:0}}>&rarr; {m.projectName}</button>
            {u!=="normal"&&<div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:u==="urgent"?"#f87171":GOLD,border:"1px solid "+(u==="urgent"?"#f87171":GOLD),padding:"3px 9px",borderRadius:4,whiteSpace:"nowrap",flexShrink:0}}>{u==="urgent"?"! Urgent":"Soon"}</div>}
          </div>
        </div>;})}
      </div>
    </div>}

    {myProjects.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Projects I Own</SectionTitle>
      <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(300px,1fr))",gap:12}}>
        {myProjects.map(p=><div key={p.id} onClick={()=>onSelect(p)} style={{background:CARD,border:"1px solid "+BORDER,borderRadius:10,padding:"18px 20px",cursor:"pointer",borderLeft:"4px solid "+getGroupColor(p.group)}} onMouseEnter={e=>e.currentTarget.style.borderColor=GOLD} onMouseLeave={e=>e.currentTarget.style.borderColor=BORDER}>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",marginBottom:8}}>
            <div style={{fontFamily:"'Times New Roman',serif",fontSize:15,fontWeight:600,color:"#eee",flex:1,marginRight:10,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.name}</div>
            <StatusBadge status={p.status} small/>
          </div>
          <div style={{fontFamily:"'Crimson Pro',serif",fontSize:13,color:"#777",marginBottom:10,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.description}</div>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}><PriorityBadge priority={p.priority}/><span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:GOLD}}>{p.deadline}</span></div>
        </div>)}
      </div>
    </div>}

    {myPhases.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Phases Assigned to Me</SectionTitle>
      <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:10,overflow:"hidden"}}>
        <table style={{width:"100%",borderCollapse:"collapse"}}>
          <thead><tr style={{borderBottom:"1px solid "+BORDER}}>{["Project","Timeline","Checkpoint","Deliverable","Status"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"9px 14px",background:"#252525",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:10,letterSpacing:"0.1em",textTransform:"uppercase"}}>{h}</th>)}</tr></thead>
          <tbody>{myPhases.map((ph,i)=><tr key={i} style={{borderBottom:i<myPhases.length-1?"1px solid "+BORDER:"none",cursor:"pointer"}} onClick={()=>onSelect(ph.project)}>
            <td style={{padding:"11px 14px",fontFamily:"'DM Mono',monospace",fontSize:13,color:GOLD,whiteSpace:"nowrap"}}>{ph.projectName}</td>
            <td style={{padding:"11px 14px",fontFamily:"'DM Mono',monospace",fontSize:11,color:"#888",whiteSpace:"nowrap"}}>{ph.timeline}</td>
            <td style={{padding:"11px 14px",fontSize:13,color:"#ccc",lineHeight:1.5}}>{ph.checkpoint}</td>
            <td style={{padding:"11px 14px",fontSize:13,color:"#888"}}>{ph.deliverable||"--"}</td>
            <td style={{padding:"11px 14px"}}><StatusBadge status={ph.status} small/></td>
          </tr>)}</tbody>
        </table>
      </div>
    </div>}

    {myUpdates.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Status Updates</SectionTitle>
      <div style={{display:"flex",flexDirection:"column",gap:10}}>
        {myUpdates.map(({project:p,latest},i)=><div key={i} style={{background:CARD,border:"1px solid "+BORDER,borderRadius:8,padding:"16px 22px",display:"grid",gridTemplateColumns:"1fr auto",gap:16,alignItems:"center"}}>
          <div>
            <div style={{fontFamily:"'Times New Roman',serif",fontSize:14,fontWeight:600,color:"#eee",marginBottom:4,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.name}</div>
            <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555",marginBottom:6}}>{latest.date}</div>
            <div style={{fontFamily:"'Crimson Pro',serif",fontSize:14,color:"#aaa",lineHeight:1.5}}>{latest.notes}</div>
          </div>
          <button onClick={()=>onSelect(p)} style={{background:"none",border:"1px solid "+GOLD,color:GOLD,borderRadius:6,padding:"7px 16px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",whiteSpace:"nowrap"}}>View &rarr;</button>
        </div>)}
      </div>
    </div>}

    {stakeProjects.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Projects I'm a Stakeholder On</SectionTitle>
      <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:10,overflow:"hidden"}}>
        <table style={{width:"100%",borderCollapse:"collapse"}}>
          <thead><tr style={{borderBottom:"1px solid "+BORDER}}>{["Project","Group","Status","My Role","Involvement","Check-in"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"9px 14px",background:"#252525",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:10,letterSpacing:"0.1em",textTransform:"uppercase"}}>{h}</th>)}</tr></thead>
          <tbody>{stakeProjects.map(({project:p,role,involvement,communication},i)=><tr key={i} onClick={()=>onSelect(p)} style={{borderBottom:i<stakeProjects.length-1?"1px solid "+BORDER:"none",cursor:"pointer"}} onMouseEnter={e=>Array.from(e.currentTarget.cells).forEach(c=>c.style.background="rgba(207,184,124,0.05)")} onMouseLeave={e=>Array.from(e.currentTarget.cells).forEach(c=>c.style.background="")}>
            <td style={{padding:"12px 14px",fontFamily:"'Times New Roman',serif",fontSize:14,fontWeight:600,color:"#eee",borderLeft:"3px solid "+getGroupColor(p.group)}}>{p.name}</td>
            <td style={{padding:"12px 14px"}}><span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:getGroupColor(p.group)}}>{p.group}</span></td>
            <td style={{padding:"12px 14px"}}><StatusBadge status={p.status} small/></td>
            <td style={{padding:"12px 14px"}}><span style={{fontFamily:"'DM Mono',monospace",fontSize:11,fontWeight:600,padding:"3px 9px",borderRadius:4,background:role==="Contributor"?"rgba(96,165,250,0.15)":role==="Advisor"?"rgba(207,184,124,0.15)":"rgba(107,114,128,0.15)",color:role==="Contributor"?"#60a5fa":role==="Advisor"?GOLD:"#9ca3af"}}>{role}</span></td>
            <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:11,fontWeight:600,color:involvement==="High"?"#f87171":involvement==="Medium"?GOLD:"#6b7280"}}>{involvement}</td>
            <td style={{padding:"12px 14px",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#888"}}>{communication}</td>
          </tr>)}</tbody>
        </table>
      </div>
    </div>}

    {past.length>0&&<div style={{marginBottom:32}}>
      <SectionTitle>Past Meetings</SectionTitle>
      <div style={{display:"flex",flexDirection:"column",gap:8}}>
        {past.slice(0,5).map((m,i)=><div key={i} style={{background:"#191919",border:"1px solid "+BORDER,borderRadius:8,padding:"12px 22px",opacity:0.65}}>
          <div style={{display:"flex",alignItems:"center",gap:16,flexWrap:"wrap"}}>
            <div style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555",minWidth:110,flexShrink:0}}>{fmtD(m.date)}</div>
            <div style={{flex:1,minWidth:0}}><span style={{fontFamily:"'Times New Roman',serif",fontSize:14,color:"#777"}}>{m.title}</span><span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#444",marginLeft:10}}>&#128101; {m.attendees}</span></div>
            <button onClick={()=>onSelect(m.project)} style={{background:"none",border:"1px solid "+BORDER,color:"#555",borderRadius:5,padding:"4px 10px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",flexShrink:0}}>&rarr; {m.projectName}</button>
          </div>
        </div>)}
      </div>
    </div>}
  </div>;
}

function App() {
  const [projects, setProjects]       = useState([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [selected, setSelected]       = useState(null);
  const [search, setSearch]           = useState("");
  const [fStatus, setFStatus]         = useState("All");
  const [fGroup, setFGroup]           = useState("All");
  const [mainTab, setMainTab]         = useState("all");
  const [nameInput, setNameInput]     = useState("");
  const [nameActive, setNameActive]   = useState("");
  const [suggestions, setSuggestions] = useState([]);

  function fetchData() {
    setLoading(true); setError(null);
    fetch(SCRIPT_URL)
      .then(r=>{ if(!r.ok) throw new Error("Server returned "+r.status); return r.json(); })
      .then(data=>{ setProjects(data); setLastUpdated(new Date()); setLoading(false); })
      .catch(err=>{ setError(err.message); setLoading(false); });
  }
  useEffect(()=>{ fetchData(); },[]);

  const people = Array.from(new Set(projects.flatMap(p=>{
    const n=[p.owner];
    (p.stakeholders||[]).forEach(s=>n.push(s.name));
    (p.phases||[]).forEach(ph=>n.push(ph.owner));
    (p.meetings||[]).forEach(m=>(m.attendees||"").split(",").forEach(a=>n.push(a.trim())));
    return n.filter(Boolean);
  }))).sort();

  const allGroups   = ["All",...Array.from(new Set(projects.map(p=>p.group).filter(Boolean)))];
  const allStatuses = ["All",...Object.keys(STATUS_COLORS)];
  const filtered = projects.filter(p=>{
    const s=search.toLowerCase();
    return((p.name||"").toLowerCase().includes(s)||(p.description||"").toLowerCase().includes(s)||(p.owner||"").toLowerCase().includes(s))
      &&(fStatus==="All"||p.status===fStatus)&&(fGroup==="All"||p.group===fGroup);
  });
  const grouped = allGroups.filter(g=>g!=="All").reduce((acc,g)=>{acc[g]=filtered.filter(p=>p.group===g);return acc;},{});

  function handleNameInput(val){ setNameInput(val); setSuggestions(val.length>=2?people.filter(n=>n.toLowerCase().includes(val.toLowerCase())).slice(0,6):[]); }
  function selectName(n){ setNameActive(n); setNameInput(n); setSuggestions([]); setMainTab("mine"); }

  if(loading) return <LoadingScreen/>;
  if(error)   return <ErrorScreen message={error} onRetry={fetchData}/>;
  if(selected) return <ProjectDetail project={selected} onBack={()=>setSelected(null)}/>;

  return <div style={{minHeight:"100vh",background:DARK,color:"#e5e5e5"}}>
    <div style={{background:BLACK,borderBottom:"1px solid "+BORDER,padding:"0 32px",position:"sticky",top:0,zIndex:10}}>
      <div style={{display:"flex",alignItems:"center",gap:16,padding:"16px 0",flexWrap:"wrap"}}>
        <div style={{display:"flex",alignItems:"center",gap:12,flexShrink:0}}>
          <div style={{width:32,height:32,borderRadius:6,background:GOLD,display:"flex",alignItems:"center",justifyContent:"center"}}>
            <span style={{color:BLACK,fontWeight:900,fontFamily:"serif",fontSize:16}}>V</span>
          </div>
          <div>
            <div style={{fontFamily:"'Times New Roman',serif",fontSize:18,fontWeight:700,color:"#fff"}}>Vanderbilt Athletics</div>
            <div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:"#666",letterSpacing:"0.1em",textTransform:"uppercase"}}>Project Tracker</div>
          </div>
        </div>
        <div style={{display:"flex",gap:4,background:"#252525",borderRadius:8,padding:4,flexShrink:0}}>
          {[["all","All Projects"],["mine","My View"]].map(([k,l])=><button key={k} onClick={()=>setMainTab(k)} style={{background:mainTab===k?(k==="mine"?GOLD:"#333"):"none",border:"none",color:mainTab===k?(k==="mine"?BLACK:"#fff"):"#666",borderRadius:5,padding:"6px 16px",fontFamily:"'DM Mono',monospace",fontSize:12,cursor:"pointer",fontWeight:mainTab===k?700:400}}>{l}</button>)}
        </div>
        <div style={{flex:1}}/>
        {lastUpdated&&<div style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:"#444",whiteSpace:"nowrap"}}>Updated {lastUpdated.toLocaleTimeString()}</div>}
        <button onClick={fetchData} className="fbtn" style={{background:"none",border:"1px solid "+BORDER,color:"#888",borderRadius:6,padding:"7px 14px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",whiteSpace:"nowrap",flexShrink:0}}>&#8635; Refresh</button>
        <div style={{position:"relative",flexShrink:0}}>
          {mainTab==="all"
            ?<input placeholder="Search projects..." value={search} onChange={e=>setSearch(e.target.value)} style={{background:"#252525",border:"1px solid "+BORDER,borderRadius:6,padding:"8px 14px",color:"#ccc",fontFamily:"'DM Mono',monospace",fontSize:12,outline:"none",width:200}}/>
            :<div>
              <input placeholder="Search your name..." value={nameInput} onChange={e=>handleNameInput(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"&&nameInput)selectName(nameInput);}} style={{background:nameActive?"rgba(207,184,124,0.08)":"#252525",border:"1px solid "+(nameActive?GOLD:BORDER),borderRadius:6,padding:"8px 14px",color:"#ccc",fontFamily:"'DM Mono',monospace",fontSize:12,outline:"none",width:220}}/>
              {suggestions.length>0&&<div style={{position:"absolute",top:"100%",left:0,right:0,background:"#1e1e1e",border:"1px solid "+BORDER,borderRadius:6,marginTop:4,zIndex:100,overflow:"hidden"}}>
                {suggestions.map(n=><div key={n} className="sugg" onClick={()=>selectName(n)} style={{padding:"9px 14px",cursor:"pointer",fontFamily:"'DM Mono',monospace",fontSize:12,color:"#aaa",borderBottom:"1px solid "+BORDER}}>{n}</div>)}
              </div>}
            </div>}
        </div>
      </div>
      {mainTab==="all"&&<div style={{display:"flex",gap:8,paddingBottom:12,flexWrap:"wrap"}}>
        <span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555",alignSelf:"center",marginRight:4}}>FILTER:</span>
        {allStatuses.map(s=><button key={s} className="fbtn" onClick={()=>setFStatus(s)} style={{background:fStatus===s?GOLD:"none",border:"1px solid "+(fStatus===s?GOLD:BORDER),color:fStatus===s?BLACK:"#777",borderRadius:4,padding:"4px 12px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",fontWeight:fStatus===s?700:400}}>{s}</button>)}
        <div style={{width:1,background:BORDER,margin:"0 4px"}}/>
        {allGroups.map(g=><button key={g} className="fbtn" onClick={()=>setFGroup(g)} style={{background:fGroup===g?getGroupColor(g):"none",border:"1px solid "+(fGroup===g?getGroupColor(g):BORDER),color:fGroup===g?BLACK:"#777",borderRadius:4,padding:"4px 12px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer",fontWeight:fGroup===g?700:400}}>{g}</button>)}
      </div>}
      {mainTab==="mine"&&<div style={{height:12}}/>}
    </div>

    {mainTab==="mine"&&(nameActive
      ?<MyView name={nameActive} projects={projects} onSelect={p=>setSelected(p)}/>
      :<div style={{padding:"80px 32px",textAlign:"center"}}>
        <div style={{fontFamily:"'Times New Roman',serif",fontSize:26,color:"#333",marginBottom:10}}>Who are you?</div>
        <div style={{fontFamily:"'DM Mono',monospace",fontSize:12,color:"#444",marginBottom:24}}>Type your name in the search bar above</div>
        <div style={{display:"flex",flexWrap:"wrap",gap:8,justifyContent:"center",maxWidth:600,margin:"0 auto"}}>
          {people.slice(0,12).map(n=><button key={n} onClick={()=>selectName(n)} style={{background:CARD,border:"1px solid "+BORDER,color:"#777",borderRadius:20,padding:"6px 14px",fontFamily:"'DM Mono',monospace",fontSize:11,cursor:"pointer"}} onMouseEnter={e=>{e.currentTarget.style.borderColor=GOLD;e.currentTarget.style.color=GOLD;}} onMouseLeave={e=>{e.currentTarget.style.borderColor=BORDER;e.currentTarget.style.color="#777";}}>{n}</button>)}
        </div>
      </div>
    )}

    {mainTab==="all"&&<div style={{padding:"28px 32px"}}>
      {Object.entries(grouped).map(([group,gps])=>{
        if(!gps.length) return null;
        const gc=getGroupColor(group);
        return <div key={group} style={{marginBottom:36}}>
          <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:10}}>
            <div style={{width:12,height:12,borderRadius:"50%",background:gc}}/>
            <span style={{fontFamily:"'Times New Roman',serif",fontSize:16,fontWeight:700,color:gc}}>{group}</span>
            <span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555",background:"#252525",border:"1px solid "+BORDER,borderRadius:10,padding:"1px 8px"}}>{gps.length}</span>
          </div>
          <div style={{background:CARD,border:"1px solid "+BORDER,borderRadius:10,overflowX:"auto"}}>
            <table style={{width:"100%",minWidth:1000,borderCollapse:"collapse",tableLayout:"fixed"}}>
              <colgroup><col style={{width:190}}/><col style={{width:220}}/><col style={{width:130}}/><col style={{width:90}}/><col style={{width:140}}/><col style={{width:110}}/><col style={{width:120}}/><col style={{width:90}}/></colgroup>
              <thead><tr style={{borderBottom:"1px solid "+BORDER}}>
                {["Project Name","Description","Owner","Priority","Timeline","Status","Deadline","Budget"].map((h,i)=><th key={i} style={{textAlign:"left",padding:"10px 16px",background:"#252525",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:10,letterSpacing:"0.1em",textTransform:"uppercase",fontWeight:500,borderLeft:i===0?"3px solid "+gc:"none"}}>{h}</th>)}
              </tr></thead>
              <tbody>{gps.map((p,ri)=><tr key={p.id} className="prow" onClick={()=>setSelected(p)} style={{borderBottom:ri<gps.length-1?"1px solid "+BORDER:"none",cursor:"pointer"}}>
                <td style={{padding:"13px 16px",fontFamily:"'Times New Roman',serif",fontSize:14,fontWeight:600,color:"#eee",borderLeft:"3px solid "+gc,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.name}</td>
                <td style={{padding:"13px 16px",color:"#888",fontSize:13,fontFamily:"'Crimson Pro',serif",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.description}</td>
                <td style={{padding:"13px 16px",color:"#aaa",fontFamily:"'DM Mono',monospace",fontSize:12,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.owner}</td>
                <td style={{padding:"13px 16px"}}><PriorityBadge priority={p.priority}/></td>
                <td style={{padding:"13px 16px",color:"#888",fontFamily:"'DM Mono',monospace",fontSize:11,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.timeline}</td>
                <td style={{padding:"13px 16px"}}><StatusBadge status={p.status}/></td>
                <td style={{padding:"13px 16px",color:GOLD,fontFamily:"'DM Mono',monospace",fontSize:12,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.deadline}</td>
                <td style={{padding:"13px 16px",color:"#666",fontFamily:"'DM Mono',monospace",fontSize:12,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{p.budget}</td>
              </tr>)}</tbody>
            </table>
          </div>
        </div>;
      })}
      {!filtered.length&&<div style={{textAlign:"center",padding:"80px 0",color:"#444",fontFamily:"'DM Mono',monospace",fontSize:13}}>No projects match your filters.</div>}
      <div style={{marginTop:8,padding:"16px 24px",background:CARD,border:"1px solid "+BORDER,borderRadius:10,display:"flex",gap:32,flexWrap:"wrap",alignItems:"center"}}>
        {Object.entries(STATUS_COLORS).map(([status,colors])=>{
          const count=projects.filter(p=>p.status===status).length;
          if(!count) return null;
          return <div key={status} style={{display:"flex",alignItems:"center",gap:8}}>
            <div style={{width:8,height:8,borderRadius:"50%",background:colors.bg}}/>
            <span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#666"}}>{status}</span>
            <span style={{fontFamily:"'DM Mono',monospace",fontSize:11,color:"#999",fontWeight:600}}>{count}</span>
          </div>;
        })}
        <div style={{marginLeft:"auto",fontFamily:"'DM Mono',monospace",fontSize:11,color:"#555"}}>{projects.length} total projects</div>
      </div>
    </div>}
  </div>;
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
  </script>
</body>
</html>
