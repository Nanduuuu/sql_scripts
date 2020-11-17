-- Create log record table
CREATE TABLE `logs` (
  `log_tbl_id` int unsigned NOT NULL AUTO_INCREMENT,
  `log_head` text,
  `query_type` enum('delete','alter','update','insert','create') DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `stop_time` datetime DEFAULT NULL,
  `activity_time` time DEFAULT '00:00:00',
  `rows_affected` int DEFAULT NULL,
  `status` enum('started','locked','continuing','rolled back','completed','canceled','failed') DEFAULT NULL,
  `comment` text,
  PRIMARY KEY (`log_tbl_id`)) engine=InnoDB;
