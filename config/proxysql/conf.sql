DELETE FROM mysql_servers;
INSERT INTO mysql_servers (hostgroup_id,hostname,port,max_replication_lag, max_connections) VALUES (0,'server01',3306,1, 1);
DELETE FROM mysql_replication_hostgroups;
INSERT INTO mysql_replication_hostgroups(writer_hostgroup, reader_hostgroup) VALUES (0,1);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

DELETE FROM mysql_users;
INSERT INTO mysql_users (username,password,active,default_hostgroup) values ('root','root',1,0);
INSERT INTO mysql_users (username,password,active,default_hostgroup) values ('john', 'john', 1,0); 
INSERT INTO mysql_users (username,password,active,default_hostgroup) values ('mary', 'mary', 1,0);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK; 

DELETE FROM mysql_query_rules;
INSERT INTO mysql_query_rules (rule_id,active,match_digest,destination_hostgroup,apply) VALUES (1,0,'^SELECT.*FOR UPDATE',0,1),(2,0,'^SELECT',1,1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;

LOAD ADMIN VARIABLES TO RUNTIME;
SAVE ADMIN VARIABLES TO DISK;
