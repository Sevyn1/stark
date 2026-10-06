const {test,before,after,beforeEach}=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,collection,getDocs,query,where,writeBatch,arrayUnion,arrayRemove,deleteDoc,serverTimestamp,Timestamp}=require('firebase/firestore');
let env;
const profile=(uid,org='',manager=false)=>({uid,firstName:uid,lastName:'Test',email:`${uid}@example.test`,isAdmin:manager,organisation:org,role:'Developer',phone:'',profilePic:''});
const org=(name,manager,employees)=>({id:name,name,avatar:'',description:'',managers:[manager],employees,prospectiveEmployees:[]});
const db=uid=>env.authenticatedContext(uid,{email:`${uid}@example.test`}).firestore();
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-stark-rules',firestore:{host:'127.0.0.1',port:8091,rules:fs.readFileSync(path.join(__dirname,'../firestore.rules'),'utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  const s=ctx.firestore();const b=writeBatch(s);
  for(const [uid,o,m] of [['ma','A',true],['mb','B',true],['e','A',false],['other','A',false],['x','B',false],['u','',false]])b.set(doc(s,'users',uid),profile(uid,o,m));
  b.set(doc(s,'organisations','A'),org('A','ma',['e','other']));b.set(doc(s,'organisations','B'),org('B','mb',['x']));
  b.set(doc(s,'employeeDirectory','u'),{uid:'u',firstName:'u',lastName:'Test',email:'u@example.test',isAdmin:false,organisation:''});
  b.set(doc(s,'projects','A::Portal'),{name:'Portal',organisationName:'A',managerId:'ma',employeeIds:['e'],taskIds:['Task'],status:'ongoing'});
  b.set(doc(s,'tasks','A::Task'),{taskName:'Task',projectName:'Portal',organisationName:'A',managerId:'ma',employeeId:'e',description:'Check',status:'ongoing'});
  b.set(doc(s,'messageGroup','A'),{name:'A',membersUid:['ma','e','other']});await b.commit();
 });
});
test('anonymous clients cannot read profiles or tasks',async()=>{const s=env.unauthenticatedContext().firestore();await assertFails(getDoc(doc(s,'users','e')));await assertFails(getDoc(doc(s,'tasks','A::Task')));});
test('users cannot escalate manager authority or change their identity',async()=>{await assertFails(updateDoc(doc(db('e'),'users','e'),{isAdmin:true}));await assertFails(updateDoc(doc(db('e'),'users','e'),{uid:'ma'}));});
test('users cannot self-join another workspace',async()=>{await assertFails(updateDoc(doc(db('u'),'users','u'),{organisation:'A'}));});
test('profile edits are permitted while email and authority remain immutable',async()=>{await assertSucceeds(updateDoc(doc(db('e'),'users','e'),{firstName:'Jamie',phone:'123'}));await assertFails(updateDoc(doc(db('e'),'users','e'),{email:'someone@example.test'}));});
test('managers cannot access another workspace project or task',async()=>{await assertFails(getDoc(doc(db('mb'),'projects','A::Portal')));await assertFails(updateDoc(doc(db('mb'),'tasks','A::Task'),{status:'done'}));});
test('assigned employees can update only task status',async()=>{await assertSucceeds(updateDoc(doc(db('e'),'tasks','A::Task'),{status:'done'}));await assertFails(updateDoc(doc(db('e'),'tasks','A::Task'),{employeeId:'other'}));await assertFails(updateDoc(doc(db('e'),'tasks','A::Task'),{description:'Rewrite'}));});
test('other employees cannot modify an unassigned task',async()=>{await assertFails(updateDoc(doc(db('other'),'tasks','A::Task'),{status:'done'}));});
test('project permissions preserve workspace and manager identity',async()=>{await assertSucceeds(updateDoc(doc(db('ma'),'projects','A::Portal'),{status:'done'}));await assertFails(updateDoc(doc(db('ma'),'projects','A::Portal'),{organisationName:'B'}));});
test('task queries require workspace scoping',async()=>{await assertSucceeds(getDocs(query(collection(db('e'),'tasks'),where('organisationName','==','A'))));await assertFails(getDocs(collection(db('e'),'tasks')));});
test('employee search exposes directory entries, not private unenrolled profiles',async()=>{await assertSucceeds(getDocs(collection(db('ma'),'employeeDirectory')));await assertFails(getDoc(doc(db('ma'),'users','u')));await assertFails(getDocs(collection(db('e'),'employeeDirectory')));});
test('workspace managers cannot rewrite workspace ownership',async()=>{await assertFails(updateDoc(doc(db('ma'),'organisations','A'),{managers:['mb']}));});
test('new workspace and manager membership must be created together',async()=>{
 const s=db('new');await assertSucceeds(setDoc(doc(s,'users','new'),profile('new','',true)));
 await assertFails(setDoc(doc(s,'organisations','N'),org('N','new',[])));
 const b=writeBatch(s);b.set(doc(s,'organisations','N'),org('N','new',[]));b.update(doc(s,'users','new'),{organisation:'N'});b.set(doc(s,'messageGroup','N'),{name:'N',membersUid:['new']});await assertSucceeds(b.commit());
});
test('employee signup can create its minimal invitation directory entry atomically',async()=>{const s=db('fresh');const b=writeBatch(s);b.set(doc(s,'users','fresh'),profile('fresh'));b.set(doc(s,'employeeDirectory','fresh'),{uid:'fresh',firstName:'fresh',lastName:'Test',email:'fresh@example.test',isAdmin:false,organisation:''});await assertSucceeds(b.commit());});
test('invitation acceptance joins only the invited workspace atomically',async()=>{
 const m=db('ma');const invite={organisationName:'A',receiverId:'u',managerId:'ma',status:'pending',sentAt:1,actionAt:1};
 const send=writeBatch(m);send.update(doc(m,'organisations','A'),{prospectiveEmployees:arrayUnion('u')});send.set(doc(m,'invites','u'),invite);await assertSucceeds(send.commit());
 const s=db('u');await assertFails(getDoc(doc(s,'users','ma')));await assertFails(getDoc(doc(s,'organisations','A')));await assertFails(updateDoc(doc(s,'users','u'),{organisation:'A'}));
 const b=writeBatch(s);b.update(doc(s,'invites','u'),{status:'accepted',actionAt:2});b.update(doc(s,'users','u'),{organisation:'A'});b.update(doc(s,'organisations','A'),{employees:arrayUnion('u'),prospectiveEmployees:arrayRemove('u')});b.update(doc(s,'messageGroup','A'),{membersUid:arrayUnion('u')});b.delete(doc(s,'employeeDirectory','u'));await assertSucceeds(b.commit());
});
test('workspace text messages enforce sender identity and reject live images',async()=>{
 const msg={senderId:'e',senderUsername:'e Test',senderProfilePic:'',recieverid:'A',text:'Hello',type:'text',timeSent:serverTimestamp(),isSeen:false};
 await assertSucceeds(setDoc(doc(db('e'),'messageGroup','A','messages','ok'),msg));
 await assertFails(setDoc(doc(db('e'),'messageGroup','A','messages','spoof'),{...msg,senderId:'ma'}));
 await assertFails(setDoc(doc(db('e'),'messageGroup','A','messages','image'),{...msg,type:'image'}));
 await assertFails(getDocs(collection(db('x'),'messageGroup','A','messages')));
});
test('employees cannot alter attendance totals',async()=>{await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'attendanceRecords','A::today'),{organisationName:'A',present:[],absent:['e'],early:[],late:[]}));await assertFails(updateDoc(doc(db('e'),'attendanceRecords','A::today'),{present:['e']}));await assertSucceeds(updateDoc(doc(db('ma'),'attendanceRecords','A::today'),{present:['e'],absent:[]}));});

test('manager can create a scoped project and task but cannot forge another project link',async()=>{
 const s=db('ma');
 const project={name:'New',organisationName:'A',managerId:'ma',employeeIds:['e'],taskIds:[],status:'ongoing'};
 await assertSucceeds(setDoc(doc(s,'projects','A::New'),project));
 const task={taskName:'New task',projectName:'New',projectId:'A::New',organisationName:'A',managerId:'ma',employeeId:'e',description:'Check',status:'ongoing'};
 await assertSucceeds(setDoc(doc(s,'tasks','A::New task'),task));
 await assertFails(setDoc(doc(s,'tasks','A::bad'),{...task,projectId:'B::Missing'}));
 await assertFails(setDoc(doc(db('e'),'tasks','A::employee'),task));
});
test('invite rejection removes only the recipient from prospective membership',async()=>{
 const m=db('ma');const b=writeBatch(m);b.update(doc(m,'organisations','A'),{prospectiveEmployees:arrayUnion('u')});b.set(doc(m,'invites','u'),{organisationName:'A',receiverId:'u',managerId:'ma',status:'pending',sentAt:1,actionAt:1});await assertSucceeds(b.commit());
 const s=db('u');const reject=writeBatch(s);reject.update(doc(s,'organisations','A'),{prospectiveEmployees:arrayRemove('u')});reject.delete(doc(s,'invites','u'));await assertSucceeds(reject.commit());
});
test('manager removal clears membership and restores the minimal directory atomically',async()=>{
 const s=db('ma');const b=writeBatch(s);b.delete(doc(s,'invites','e'));b.update(doc(s,'organisations','A'),{employees:arrayRemove('e'),prospectiveEmployees:arrayRemove('e')});b.update(doc(s,'users','e'),{organisation:''});b.set(doc(s,'employeeDirectory','e'),{uid:'e',firstName:'e',lastName:'Test',email:'e@example.test',isAdmin:false,organisation:''});b.update(doc(s,'messageGroup','A'),{membersUid:arrayRemove('e')});await assertSucceeds(b.commit());
 await assertFails(getDoc(doc(db('e'),'tasks','A::Task')));
});
test('new employees can query memberships and their invitation inbox before joining',async()=>{
 const s=db('u');
 await assertSucceeds(getDocs(query(collection(s,'organisations'),where('employees','array-contains','u'))));
 await assertSucceeds(getDocs(query(collection(s,'invites'),where('receiverId','==','u'))));
 await assertFails(getDocs(collection(s,'invites')));
 await assertFails(getDocs(query(collection(s,'invites'),where('receiverId','==','e'))));
});

async function seedAttendance(closed=false){
 await env.withSecurityRulesDisabled(async ctx=>{const s=ctx.firestore();await setDoc(doc(s,'attendanceRecords','A::today'),{organisationName:'A',dayKey:'today',windowStart:Timestamp.fromMillis(Date.now()-3600000),windowEnd:Timestamp.fromMillis(Date.now()+(closed?-1000:3600000)),startAt:Timestamp.fromMillis(Date.now()-1800000)});await setDoc(doc(s,'attendance','A::today::e'),{organisationName:'A',employeeId:'e',recordId:'A::today',dayKey:'today',status:'notsigned',timeIn:null,timeOut:null});});
}
test('employees self-check in with server time and cannot alter colleagues',async()=>{await seedAttendance();const s=db('e');await assertFails(updateDoc(doc(s,'attendance','A::today::e'),{status:'signed',timeIn:Timestamp.fromMillis(1)}));await assertSucceeds(updateDoc(doc(s,'attendance','A::today::e'),{status:'signed',timeIn:serverTimestamp()}));await assertFails(updateDoc(doc(db('other'),'attendance','A::today::e'),{status:'signed',timeIn:serverTimestamp()}));});
test('employees cannot overwrite a check-in or their identity',async()=>{await seedAttendance();const s=db('e');const r=doc(s,'attendance','A::today::e');await assertSucceeds(updateDoc(r,{status:'signed',timeIn:serverTimestamp()}));await assertFails(updateDoc(r,{timeIn:serverTimestamp()}));await assertFails(updateDoc(r,{employeeId:'other'}));});
test('employees check out once after their server-timed check-in',async()=>{await seedAttendance();const s=db('e');const r=doc(s,'attendance','A::today::e');await assertFails(updateDoc(r,{timeOut:serverTimestamp()}));await assertSucceeds(updateDoc(r,{status:'signed',timeIn:serverTimestamp()}));await assertSucceeds(updateDoc(r,{timeOut:serverTimestamp()}));await assertFails(updateDoc(r,{timeOut:serverTimestamp()}));});
test('closed workdays reject employee check-ins',async()=>{await seedAttendance(true);await assertFails(updateDoc(doc(db('e'),'attendance','A::today::e'),{status:'signed',timeIn:serverTimestamp()}));});
test('employees see only their own attendance entries',async()=>{await seedAttendance();const s=db('e');await assertSucceeds(getDocs(query(collection(s,'attendance'),where('organisationName','==','A'),where('employeeId','==','e'))));await assertFails(getDocs(query(collection(s,'attendance'),where('organisationName','==','A'))));await assertFails(getDoc(doc(db('other'),'attendance','A::today::e')));});

test('managers cannot forge or overwrite an employee check-in',async()=>{await seedAttendance();await assertFails(updateDoc(doc(db('ma'),'attendance','A::today::e'),{status:'signed',timeIn:serverTimestamp()}));});
test('members invited after workday opening can create only their own check-in entry',async()=>{await seedAttendance();const s=db('other');const entry={organisationName:'A',employeeId:'other',recordId:'A::today',dayKey:'today',status:'signed',timeIn:serverTimestamp(),timeOut:null};await assertSucceeds(setDoc(doc(s,'attendance','A::today::other'),entry));await assertFails(setDoc(doc(s,'attendance','A::today::e'),{...entry,employeeId:'e'}));});

const directMessage=(uid,room)=>({senderId:uid,senderUsername:uid+' Test',senderProfilePic:'',recieverid:room,text:'Private message',type:'text',timeSent:serverTimestamp(),isSeen:false});
async function openPrivateRoom(){await assertSucceeds(setDoc(doc(db('e'),'directConversations','A::e::other'),{organisationName:'A',participantIds:['e','other'],createdBy:'e',createdAt:serverTimestamp()}));}
test('direct conversations admit only two people in the same workspace',async()=>{await openPrivateRoom();await assertFails(setDoc(doc(db('e'),'directConversations','A::e::x'),{organisationName:'A',participantIds:['e','x'],createdBy:'e',createdAt:serverTimestamp()}));await assertFails(setDoc(doc(db('e'),'directConversations','A::e::e'),{organisationName:'A',participantIds:['e','e'],createdBy:'e',createdAt:serverTimestamp()}));});
test('private messages are visible to participants, not workspace managers or outsiders',async()=>{await openPrivateRoom();await assertSucceeds(setDoc(doc(db('e'),'directConversations','A::e::other','messages','hello'),directMessage('e','A::e::other')));await assertSucceeds(getDocs(collection(db('other'),'directConversations','A::e::other','messages')));await assertFails(getDocs(collection(db('ma'),'directConversations','A::e::other','messages')));await assertFails(getDoc(doc(db('ma'),'directConversations','A::e::other')));await assertFails(getDocs(collection(db('x'),'directConversations','A::e::other','messages')));});
test('direct message identity and server timestamp cannot be forged',async()=>{await openPrivateRoom();const s=db('e');await assertFails(setDoc(doc(s,'directConversations','A::e::other','messages','spoof'),{...directMessage('e','A::e::other'),senderId:'other'}));await assertFails(setDoc(doc(s,'directConversations','A::e::other','messages','name'),{...directMessage('e','A::e::other'),senderUsername:'Someone else'}));await assertFails(setDoc(doc(s,'directConversations','A::e::other','messages','clock'),{...directMessage('e','A::e::other'),timeSent:Timestamp.fromMillis(1)}));});
test('conversation participants cannot be changed after creation',async()=>{await openPrivateRoom();await assertFails(updateDoc(doc(db('e'),'directConversations','A::e::other'),{participantIds:['e','ma']}));});
