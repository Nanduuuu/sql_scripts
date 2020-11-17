delimiter &&
create definer ='dbaStack'@'localhost' procedure purge_radacct() language sql modifies sql data
purge_code:begin
    -- Variable Declaration
    DECLARE radacct_id int;         -- store radacctid
    DECLARE row_count int;          -- store row count
    DECLARE last_inserted_id int;   -- store last_insert_id
    DECLARE dml_action varchar(100) default 'started';
    DECLARE live_comment varchar(200) default 'logging initiated';
    -- Handler Condition for 1205, 1213
    DECLARE lock_wait_err condition for 1205 ;
    DECLARE deadlock_err condition for 1213;
    -- Handler Declaration for lock_wait_timeout
    DECLARE exit handler for lock_wait_err -- Error: 1205 SQLSTATE: HY000 (ER_LOCK_WAIT_TIMEOUT)
        begin
        set dml_action = 'rolled back'; set live_comment = 'lock wait happened: transaction rolled back';
        update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time),
        status=dml_action, comment=live_comment where log_tbl_id=last_inserted_id;
        rollback ;
        end ;
    -- Handle Declaration for er_lock_deadlock
    DECLARE exit handler for deadlock_err -- Error 1213 SQLSTATE 40001: HY000 (ER_LOCK_DEADLOCK)
        begin
            set dml_action = 'rolled back'; set live_comment = 'deadlock found; transaction rolled back';
            update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time),
            status=dml_action, comment=live_comment where log_tbl_id=last_inserted_id;
        end ;
    -- logging
    insert into radius13.logs (log_head,query_type,start_time,status,comment) values
                              ('Purge Radacct Table','delete',NOW(),dml_action,live_comment);
    select last_insert_id() into last_inserted_id;
    -- find radacctid and store into variable radacct_id
    START TRANSACTION ;
    select radacctid into radacct_id from radius13.radacct where acctstoptime < (NOW() - interval 3 DAY ) and
           acctstoptime is not null order by radacctid desc limit 1 ;
    -- using radacctid found to calculate rows to delete
    -- select count(*) into row_count from radius13.radacct where acctstoptime is not null and radacctid <= radacct_id;
    select sum(if(acctstoptime,1,0)) into row_count from radius13.radacct where radacctid <= radacct_id and acctstoptime is not null;
    set live_comment = 'Stage 1 Completed';
    -- logging
    update radius13.logs set stop_time=NOW(), rows_affected=row_count, activity_time=timediff(stop_time,start_time),
                             comment=live_comment where log_tbl_id=last_inserted_id;
    COMMIT ;
    -- purge operation on radacct table using found radacct_id and row_count
    -- looping starts
    looper_deletes : loop
        set row_count = row_count - 1000;
        delete from radius13.radacct where radacctid <= radacct_id and acctstoptime is not null limit 1000;
     if row_count <= 0 then
        -- logging
        update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), status='completed',
                                 comment='Purging Completed' where log_tbl_id=last_inserted_id;
        leave purge_code;
        leave looper_deletes;
     else
    -- logging
        update radius13.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), comment='Iterating Purge',
                                 status='continuing' where log_tbl_id=last_inserted_id;
        iterate looper_deletes;
    end if ;
    end loop looper_deletes;
    -- loop ends
end &&
delimiter ;
