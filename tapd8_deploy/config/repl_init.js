rs.initiate();
function sleep(d){
  for(var t = Date.now();Date.now() - t <= d;);
}
sleep(10000);
db = db.getSiblingDB('admin');
db.createUser({
  user: "root",
  pwd: "pass_default",
  roles: [
    {role: "root", db: "admin"}
  ]
});

db.auth('root','pass_default');
quit();