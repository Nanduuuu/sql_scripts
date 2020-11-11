-- Create event for scheduling purge-radacct
create event daily_purge_job on schedule every 1 day starts 01.00 
do 
    begin 
    call purge_radacct(); 
    end;
