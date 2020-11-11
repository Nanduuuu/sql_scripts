-- Create log record table
Create table `logs` ( `log_tbl_id` int unsigned NOT NULL AUTO_INCREMENT, `log_head` text, `dml_query` enum('delete','update','alter','insert') DEFAULT NULL,
`start_time` datetime DEFAULT NULL, `stop_time` datetime DEFAULT NULL, `activity_time` time DEFAULT '00:00:00', `rows_affected` int DEFAULT NULL,
`status` enum('started','locked','continuing','rolled back','completed','canceled','failed') DEFAULT NULL, `comment` text, PRIMARY KEY (`log_tbl_id`)) ENGINE=InnoDB
