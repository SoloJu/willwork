db = db.getSiblingDB('tapdata');
db.getCollection('Settings').update({key:'SHOW_PAGE_TITLE'},{$set:{value:0}});
db.getCollection('Settings').update({key:'PRODUCT_TITLE'},{$set:{value:'Dataplatform'}});
db.getCollection('Settings').update({key:'SHOW_QA_AND_HELP'},{$set:{value:0}});
db.getCollection('Settings').update({key:'SHOW_HOME_BUTTON'},{$set:{value:0}});
