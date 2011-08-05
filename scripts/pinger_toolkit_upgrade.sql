SET FOREIGN_KEY_CHECKS=0;
CREATE TABLE IF NOT EXISTS host_tmp as SELECT * from host;
CREATE TABLE IF NOT EXISTS metaData_tmp as SELECT * from metaData;
DROP table IF EXISTS host;
DROP table IF EXISTS metaData;

CREATE TABLE IF NOT EXISTS host (
	host BIGINT NOT NULL AUTO_INCREMENT,
	ip_name varchar(52) NOT NULL, 
	ip_number varchar(64) NOT NULL,
	ip_type enum('ipv4','ipv6')  NOT NULL default 'ipv4',
	PRIMARY KEY  (host),
	UNIQUE INDEX (ip_name, ip_number)
);

CREATE TABLE IF NOT EXISTS  metaData  (
 metaID BIGINT NOT NULL AUTO_INCREMENT,
 src_host BIGINT NOT NULL,
 dst_host BIGINT NOT NULL, 
 transport enum('icmp','tcp','udp')   NOT NULL DEFAULT 'icmp',
 packetSize smallint   NOT NULL,
 count smallint   NOT NULL,
 packetInterval smallint,
 ttl smallint,
 INDEX (src_host, dst_host, packetSize, count),
 FOREIGN KEY (src_host) references host (host),
 FOREIGN KEY (dst_host) references host (host),
 PRIMARY KEY  (metaID)
);

INSERT IGNORE INTO host (ip_name, ip_number, ip_type) 
  SELECT ip_name, ip_number, 'ipv4'
  FROM host_tmp;
INSERT IGNORE INTO metaData (metaID, src_host, dst_host, transport,  packetSize,  count,  packetInterval,  ttl ) 
  SELECT m.metaID, src.host, dst.host, m.transport, m.packetSize, m.count, m.packetInterval, m.ttl
  FROM metaData_tmp m JOIN host src on(m.ip_name_src = src.ip_name) JOIN host dst on(m.ip_name_dst = dst.ip_name);
DROP table  IF EXISTS host_tmp;
DROP table  IF EXISTS metaData_tmp;
SET FOREIGN_KEY_CHECKS=1;
