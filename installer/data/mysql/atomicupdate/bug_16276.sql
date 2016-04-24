ALTER IGNORE TABLE borrowers ADD COLUMN lastseen datetime default NULL;
ALTER IGNORE TABLE deletedborrowers ADD COLUMN lastseen datetime default NULL;
INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('TrackLastPatronActivity', '0', 'If set, the field borrowers.lastseen will be updated everytime a patron is seen', NULL, 'YesNo');
