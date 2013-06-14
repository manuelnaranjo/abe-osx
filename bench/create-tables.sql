-- MySQL dump 10.13  Distrib 5.5.31, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: benchmark
-- ------------------------------------------------------
-- Server version	5.5.31-0ubuntu0.12.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `benchrun`
--

DROP TABLE IF EXISTS `benchrun`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `benchrun` (
  `date` datetime NOT NULL,
  `benchmark` varchar(30) NOT NULL,
  `base_result` float NOT NULL,
  `status` enum('IDLE','RUNNING','DONE') NOT NULL,
  `target_arch` varchar(72) NOT NULL,
  `build_arch` varchar(72) NOT NULL,
  `build_machine` varchar(72) NOT NULL,
  `build_os` varchar(72) NOT NULL,
  `codename` varchar(72) NOT NULL,
  `enabled_cores` int(3) NOT NULL,
  `enabled_chips` int(3) NOT NULL,
  `cores_per_chip` int(3) NOT NULL,
  `threads_per_core` int(3) NOT NULL,
  `build_gcc` varchar(72) NOT NULL,
  `target_gcc` varchar(72) NOT NULL,
  `binutils_version` varchar(72) NOT NULL,
  `libc_version` varchar(72) NOT NULL,
  `peak_result` int(6) NOT NULL,
  `ram` int(11) NOT NULL,
  `benchrun` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `benchrun`
--

LOCK TABLES `benchrun` WRITE;
/*!40000 ALTER TABLE `benchrun` DISABLE KEYS */;
/*!40000 ALTER TABLE `benchrun` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `coremark`
--

DROP TABLE IF EXISTS `coremark`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `coremark` (
  `compiler_version` varchar(72) NOT NULL,
  `os_speed_mhz` int(6) NOT NULL,
  `coremark_mhz` int(6) NOT NULL,
  `coremark_core` float NOT NULL,
  `parallel_execucution` float NOT NULL,
  `eembc` float NOT NULL,
  `coremark` int(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `coremark`
--

LOCK TABLES `coremark` WRITE;
/*!40000 ALTER TABLE `coremark` DISABLE KEYS */;
/*!40000 ALTER TABLE `coremark` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eembc`
--

DROP TABLE IF EXISTS `eembc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `eembc` (
  `fixme1` int(11) NOT NULL,
  `fixme2` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eembc`
--

LOCK TABLES `eembc` WRITE;
/*!40000 ALTER TABLE `eembc` DISABLE KEYS */;
/*!40000 ALTER TABLE `eembc` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spec_2000`
--

DROP TABLE IF EXISTS `spec_2000`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `spec_2000` (
  `test` enum('CINT','CFP') NOT NULL,
  `benchmark` varchar(72) NOT NULL,
  `reference_time` time NOT NULL,
  `base_runtime` int(11) NOT NULL,
  `base_ratio` float NOT NULL,
  `runtime` int(11) NOT NULL,
  `ratio` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spec_2000`
--

LOCK TABLES `spec_2000` WRITE;
/*!40000 ALTER TABLE `spec_2000` DISABLE KEYS */;
/*!40000 ALTER TABLE `spec_2000` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `spec_2006`
--

DROP TABLE IF EXISTS `spec_2006`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `spec_2006` (
  `benchmark` varchar(72) NOT NULL,
  `base_seconds` int(11) NOT NULL,
  `base_ratio` float NOT NULL,
  `peak_seconds` int(11) NOT NULL,
  `peak_ratio` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spec_2006`
--
CREATE TABLE `tabulate` (
  `testname` varchar(72) NOT NULL,
  `version` varchar(72) NOT NULL,
  `klass` varchar(6) NOT NULL,
  `variant` varchar(72) NOT NULL,
  `subname` varchar(72) NOT NULL,
  `nsamples` int(11) NOT NULL,
  `min` float NOT NULL,
  `max` float NOT NULL,
  `best` float NOT NULL,
  `span` float NOT NULL,
  `mean` float NOT NULL,
  `std` float NOT NULL,
  `median` float NOT NULL,
  `benchrun` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

LOCK TABLES `spec_2006` WRITE;
/*!40000 ALTER TABLE `spec_2006` DISABLE KEYS */;
/*!40000 ALTER TABLE `spec_2006` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-05-17 13:33:36
