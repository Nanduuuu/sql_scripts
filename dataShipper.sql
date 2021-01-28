delimiter **
create definer ='dbaStack'@'localhost' procedure `data_shipper6` (IN purge_days int) contains sql modifies sql data
data_shipper:begin
    declare rid int;
    declare rowcount int;
    DECLARE last_inserted_id int;   -- store last_insert_id
    DECLARE dml_action varchar(100) default 'started';
    DECLARE live_comment varchar(200) default 'logging initiated';
    -- Handle Condition for 1205, 1213
    DECLARE lock_wait_err condition for 1205;
    DECLARE deadlock_err condition for 1213;
    -- Handler Declaration for lock_wait_timeout
    DECLARE exit handler for lock_wait_err -- Error: 1205 SQLSTATE: HY000 (ER_LOCK_WAIT_TIMEOUT)
    begin
        set dml_action = 'rolled back';
        set live_comment = concat('lock wait happened; transaction rolled back',' ',rowcount,' : rows deleted!');
        update radius6.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), status=dml_action,
                                comment=live_comment where log_tbl_id=last_inserted_id;
        rollback ;
    end;
    -- Handle Declaration for er_lock_deadlock
    DECLARE exit handler for deadlock_err -- Error 1213 SQLSTATE 40001: HY000 (ER_LOCK_DEADLOCK)
    begin
         set dml_action = 'rolled back';
         set live_comment = 'deadlock found; transaction rolled back';
         update radius6.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), status=dml_action, comment=live_comment where log_tbl_id=last_inserted_id;
         commit ;
    end;
    -- logging
    insert into radius6.logs (log_head,query_type,start_time,status,comment) values ('Purging Operation','delete',NOW(),dml_action,live_comment);
    select last_insert_id() into last_inserted_id;
    -- Find Radacct Id Limit For the Day
    select sql_no_cache radacctid into rid from radius6.radacct where acctstarttime <  (NOW() - interval purge_days day)  and acctstoptime is not null  order by radacctid desc limit 1;
    select rid;
    -- Compute rows to ship and purge
    select sql_no_cache sum(1) into rowcount from radius6.radacct where radacctid <= rid and acctstoptime is not null;
    update radius6.logs set stop_time=NOW(), rows_affected=rowcount, activity_time=timediff(stop_time,start_time), comment='sum rows' where log_tbl_id=last_inserted_id;
    select rowcount;
    commit ;
    -- Data Shipping
    while rowcount !=0 or rowcount > 0 do
        replace into archive6.radacct select * from radius6.radacct where radacctid <= rid  and acctstoptime is not null order by radacctid asc limit 3000;
        delete from radius6.radacct where radacctid <= rid and acctstoptime is not null order by radacctid asc limit 3000; -- delete 3000 rows per loop
        set rowcount = rowcount - 3000;
        update radius6.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), comment=concat(rowcount,' more rows to delete'), status='continuing' where log_tbl_id=last_inserted_id;
        select rowcount as 'after_deletion';
        if rowcount = 0 or rowcount < 0 then
            update radius6.logs set stop_time=NOW(), activity_time=timediff(stop_time,start_time), status='completed', comment='Purging Completed' where log_tbl_id=last_inserted_id;
            leave data_shipper;
        end if;
    end while;
end **
delimiter ;



drop procedure data_shipper7;
