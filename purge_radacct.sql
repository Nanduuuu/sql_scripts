#Create log record table
Create table `logs` ( `log_tbl_id` int unsigned NOT NULL AUTO_INCREMENT, `log_head` text, `dml_query` enum('delete','update','alter','insert') DEFAULT NULL,
`start_time` datetime DEFAULT NULL, `stop_time` datetime DEFAULT NULL, `activity_time` time DEFAULT '00:00:00', `rows_affected` int DEFAULT NULL,
`status` enum('started','locked','continuing','rolled back','completed','canceled','failed') DEFAULT NULL, `comment` text, PRIMARY KEY (`log_tbl_id`)) ENGINE=InnoDB

#sql_code : Purging Radacct Records
delimiter &&
create definer ='root'@'localhost' procedure purge_radacct() language sql modifies sql data
del_pro:begin
    -- Variable Declaration
    DECLARE radacct_id int;         -- store radacctid
    DECLARE row_count int;          -- store row count
    DECLARE last_inserted_id int;   -- store last_insert_id
    DECLARE dml_action varchar(100) default 'started';
    DECLARE live_comment varchar(200) default 'logging initiated';
    -- Handler Declaration
    DECLARE lock_wait_err condition for 1205 ;
    DECLARE exit handler for lock_wait_err -- Error: 1205 SQLSTATE: HY000 (ER_LOCK_WAIT_TIMEOUT)
    BEGIN
        set dml_action = 'rolled back';
        set live_comment = 'Transaction Rolled Back';
        update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time),
        status=dml_action, comment=live_comment where log_tbl_id=last_inserted_id;
        commit ;
    end ;
    -- logging
    insert into radius13.logs (log_head,dml_query,start_time,status,comment) values ('Radacct Purge Operation','delete',NOW(),dml_action,live_comment);
    select last_insert_id() into last_inserted_id;
    -- find radacctid and store into variable radacct_id , using radacctid found to calculate rows to delete;
    START TRANSACTION ;
    select radacctid into radacct_id from radius13.radacct where acctstoptime < (NOW() - interval 90 DAY ) and acctstoptime is not null order by radacctid desc limit 1 ;
    select count(*) into row_count from radius13.radacct where acctstoptime is not null and radacctid <= radacct_id;
    set live_comment = 'Stage 1 Completed';
    -- logging
    update radius13.logs set stop_time=NOW(), rows_affected=row_count, activity_time=timediff(stop_time,start_time), comment=live_comment where log_tbl_id=last_inserted_id;
    COMMIT ;
    -- purge operation on radacct table using found radacct_id and row_count
    -- looping starts
    looper_deletes : loop
        set row_count = row_count - 1000;
        delete from radius13.radacct where radacctid <= radacct_id and acctstoptime is not null limit 1000;
     if row_count <= 0 then
        -- logging
        update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), status='completed', comment='Purging Completed' where log_tbl_id=last_inserted_id;
        leave del_pro;
        leave looper_deletes;
     else
        -- logging
        update radius13.logs set stop_time=NOW(),activity_time=timediff(stop_time,start_time),comment='Iterating Purge', status='continuing'  where log_tbl_id=last_inserted_id;
        iterate looper_deletes;
    end if ;
    end loop looper_deletes;
    -- loop ends
end &&
delimiter ;