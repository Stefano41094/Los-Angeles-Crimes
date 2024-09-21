-- DOWNLOAD & IMPORT

-- The data is available at the following links:

-- https://data.lacity.org/Public-Safety/Crime-Data-from-2010-to-2019/63jg-8b9z
-- https://data.lacity.org/Public-Safety/Crime-Data-from-2020-to-Present/2nrs-mtv8 -- Weekly updated

-- The data can be downloaded as csv and required to be imported with text qualifier " on the following columns: 
-- Crm Cd Desc, Premis Desc, Weapon Desc, Status Desc.

-- Since there are millions of rows, selecting the correct data type by trial & error may take a long time. A more efficient alternative is to import 
-- all columns as varchar and set the appropriate types later-on. A side effect is that NULLs are imported as blank string character (''), which will 
-- require to be fixed.

-- DATA INTEGRATION

-- The data integration script is designed to drop and recreate objects like tables, functions, etc. in order to prevent errors and ensure 
-- the script is smoothly executed.

-- 1) DROP THE FOREIGN KEYS

-- Dropping the foreign keys is necessary to drop the tables. The following script is a dynamic query that drops all foreign keys in the 
-- database regardless of their object name.

DECLARE @delete_foreign_key nvarchar(max);
WITH retrieve_foreign_keys AS (
	SELECT
		--o.object_id AS constr, 
		--o.name as constraint_name, 
		--o2.name as table_name,
		--s.name AS schema_name,
		'IF OBJECT_ID(N''' + s.name + '.' + o2.name + ''') IS NOT NULL ' +
		'ALTER TABLE ' + s.name + '.' + o2.name + ' DROP CONSTRAINT ' + o.name AS Query
	FROM sys.objects o
		INNER JOIN sys.objects o2 ON o.parent_object_id = o2.object_id
		INNER JOIN  sys.schemas s ON o.schema_id = s.schema_id
	WHERE o.type = 'F'
)
SELECT @delete_foreign_key = STRING_AGG(Query,' ') 
FROM retrieve_foreign_keys
--PRINT @delete_foreign_key
EXEC sys.sp_executesql @delete_foreign_key
GO

-- 2) DROP THE TABLES.

IF OBJECT_ID(N'[Crime].[CrimesDim]') IS NOT NULL
DROP TABLE [Crime].[CrimesDim]
GO
IF OBJECT_ID(N'[Crime].[CrimesFact]') IS NOT NULL
DROP TABLE [Crime].[CrimesFact]
GO
IF OBJECT_ID(N'[Crime].[InvestigationStatus]') IS NOT NULL
DROP TABLE [Crime].[InvestigationStatus]
GO
IF OBJECT_ID(N'[Location].[District]') IS NOT NULL
DROP TABLE [Location].[District]
GO
IF OBJECT_ID(N'[Location].[LocationType]') IS NOT NULL
DROP TABLE [Location].[LocationType]
GO
IF OBJECT_ID(N'[Victim].[Ethnicity]') IS NOT NULL
DROP TABLE [Victim].[Ethnicity]
GO
IF OBJECT_ID(N'[Victim].[Sex]') IS NOT NULL
DROP TABLE [Victim].[Sex]
GO
IF OBJECT_ID(N'[Weapon].[Weapon]') IS NOT NULL
DROP TABLE [Weapon].[Weapon]
GO

-- 3) DROP AND RE-CREATE THE SCHEMAS.

DROP SCHEMA IF EXISTS Crime
DROP SCHEMA IF EXISTS Location
DROP SCHEMA IF EXISTS Victim
DROP SCHEMA IF EXISTS Weapon
GO

CREATE SCHEMA Crime		-- to host fact and dimension information about crimes
GO
CREATE SCHEMA Location	-- to host dimension info about location crimes
GO
CREATE SCHEMA Victim	-- to host dimension info about the victims
GO
CREATE SCHEMA Weapon	-- to host dimension info about the weapons
GO

-- 4) CREATE THE FACT TABLE CrimesFact that will host info such as crime date, foreign keys that represent dimensions, and other information.
 
 -- The correct data types will be applied later on, after all the necessary steps to integrate data will be performed.

IF OBJECT_ID(N'Crime.CrimesFact') IS NOT NULL
DROP TABLE Crime.CrimesFact
GO
CREATE TABLE [Crime].[CrimesFact](
	[CrimeKey] bigint PRIMARY KEY,
	[ReportDate] [varchar](5) NULL,
	[Area] [varchar](6) NULL,
	[AreaName] [varchar](7) NULL,
	[District] [varchar](8) NULL,
	[MainCrime] [varchar](9) NULL,
	[CrimeName] [varchar](10) NULL,
	[VictimAge] [varchar](11) NULL,
	[VictimSex] [varchar](12) NULL,
	[VictimEthnicity] [varchar](13) NULL,
	[LocationType] [varchar](1000),
	[LocationTypeName] [varchar](15) NULL,
	[Weapon] [varchar](16) NULL,
	[WeaponName] [varchar](17) NULL,
	[Status] [varchar](18) NULL,
	[StatusName] [varchar](19) NULL,
	[RoundedStreet] [varchar](20) NULL,
	[CrossStreet] [varchar](21) NULL,
	[Latitude] [varchar](22) NULL,
	[Longitude] [varchar](23) NULL,
)
GO

-- 5) INSERT RAW DATA INTO THE FACT TABLE CrimesFact

WITH data_union AS (
	SELECT * FROM [dbo].[Crime_Data_from_2010_to_2019]		-- previously imported from flat file
	UNION ALL
	SELECT * FROM [dbo].[Crime_Data_from_2020_to_Present]	-- previously imported from flat file
)
INSERT INTO [Crime].[CrimesFact]
	SELECT [DR_NO]
		  ,[Date Rptd]
		  ,[AREA]
		  ,[AREA NAME]
		  ,[Rpt Dist No]
		  ,[Crm Cd]
		  ,[Crm Cd Desc]
		  ,[Vict Age]
		  ,[Vict Sex] 
		  ,[Vict Descent]
		  ,[Premis Cd]
		  ,[Premis Desc]
		  ,[Weapon Used Cd] 
		  ,[Weapon Desc]
		  ,[Status]
		  ,[Status Desc]
		  ,[LOCATION]
		  ,[Cross Street]
		  ,[LAT]
		  ,[LON]
	FROM data_union
GO

-- 6) DELETE ROWS WITH NO PRIMARY KEY OR CRIME DATE

DELETE FROM [Crime].[CrimesFact]
WHERE 
	([CrimeKey] IS NULL OR [CrimeKey] = '')
	OR ([ReportDate] IS NULL OR [ReportDate] = '')
	OR [MainCrime] IS NULL
GO

-- 7) CREATE A PROCEDURE TO REPLACE ALL BLANK STRING CHARACTERS WITH NULL.
 
CREATE PROCEDURE [dbo].[sp_UpdateBlankNull]
AS
BEGIN
		
	UPDATE [Crime].[CrimesFact]
	SET [ReportDate] = NULL
	WHERE [ReportDate] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [Area] = NULL
	WHERE [Area] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [AreaName] = NULL
	WHERE [AreaName] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [District] = NULL
	WHERE [District] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [MainCrime] = NULL
	WHERE [MainCrime] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [CrimeName] = NULL
	WHERE [CrimeName] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [VictimAge] = NULL
	WHERE [VictimAge] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [VictimSex] = NULL
	WHERE [VictimSex] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [VictimEthnicity] = NULL
	WHERE [VictimEthnicity] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [LocationType] = NULL
	WHERE [LocationType] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [LocationTypeName] = NULL
	WHERE [LocationTypeName] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [Weapon] = NULL
	WHERE [Weapon] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [WeaponName] = NULL
	WHERE [WeaponName] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [Status] = NULL
	WHERE [Status] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [StatusName] = NULL
	WHERE [StatusName] = ''	
	
	UPDATE [Crime].[CrimesFact]
	SET [RoundedStreet] = NULL
	WHERE [RoundedStreet] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [CrossStreet] = NULL
	WHERE [CrossStreet] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [Latitude] = NULL
	WHERE [Latitude] = ''
	
	UPDATE [Crime].[CrimesFact]
	SET [Longitude] = NULL
	WHERE [Longitude] = ''
END
GO

EXECUTE sp_UpdateBlankNull
GO

-- 8) CREATE AND POPULATE THE DIMENSION TABLE District.

-- LAPD districts info can be downloaded & imported from the following link:
-- https://geohub.lacity.org/datasets/lahub::lapd-reporting-district/explore?location=34.020076%2C-118.411779%2C10.26

-- This file contains district keys with no match in our dataset, thereby missing data must be integrated.
-- We can split the district integration data in two parts: 1) non-missing districts 2) missing districts.

-- 8.1) Non-missing districts

-- Create a temporary table that will store the non-missing district and related info.

IF OBJECT_ID(N'tempdb..#Temp_DimDistricts') IS NOT NULL
DROP TABLE #Temp_DimDistricts
GO
CREATE TABLE #Temp_DimDistricts (
	District smallint PRIMARY KEY
	,Area varchar(29) NULL
	,Bureau varchar(30) NULL
	,DistrictShapeArea real NULL
	,DistrictShapeLength real NULL
)
GO

-- The data can be retrieved and inserted through the following query.

INSERT INTO #Temp_DimDistricts
	SELECT
			[REPDIST]
			,cf.[AreaName]
			,[BUREAU]
			,[Shape__Area]
			,[Shape__Length]
	FROM [dbo].[LAPD_Reporting_District_original] distr
	LEFT JOIN [Crime].[CrimesFact] cf
		ON distr.PREC = CAST(cf.Area AS tinyint)
	GROUP BY
			[REPDIST]
			,cf.[AreaName]
			,[BUREAU]
			,[Shape__Area]
			,[Shape__Length]
GO

-- 8.2) Missing districts

-- Create the dimension table District.

IF OBJECT_ID(N'Location.District') IS NOT NULL
DROP TABLE Location.District
GO
CREATE TABLE Location.District (
	District smallint PRIMARY KEY
	,Area varchar(32) NULL
	,Bureau varchar(33) NULL
	,DistrictShapeArea real NULL
	,DistrictShapeLength real NULL
)
GO

-- The following query uses multiple CTEs to retrieve missing data and insert into the District table.

WITH district_range AS ( -- define the first and the last district numbers for each Area/Bureau pair
	SELECT
		MIN(District) AS FirstNonMissingDistrict
		,MAX(District) AS LastNonMissingDistrict
		,Area
		,Bureau
	FROM #Temp_DimDistricts
	GROUP BY Area, Bureau
	--ORDER BY FirstNonMissingDistrict
),
district_groups AS ( -- redefine the district numbers for each Area based on the previous cte
	SELECT
		FirstNonMissingDistrict
		,LastNonMissingDistrict
		,CAST((CASE 
				WHEN FirstNonMissingDistrict < 1000 THEN LEFT(FirstNonMissingDistrict,34) + '00' 
				ELSE LEFT(FirstNonMissingDistrict,35) + '00' 
			   END) 
		 AS smallint) AS FirstDistrict
		,CAST((CASE 
				WHEN LastNonMissingDistrict < 1000 THEN LEFT(LastNonMissingDistrict,36) + '99' 
				ELSE LEFT(LastNonMissingDistrict,37) + '99' 
			   END) 
		 AS smallint) AS LastDistrict
		,Area
		,Bureau
	FROM district_range
	--ORDER BY FirstNonMissingDistrict, Bureau
),
all_districts AS ( -- retrieves the missing districts and the corresponding Area and Bureau and gather to non missing districts data
	SELECT
		CAST(cf.District AS smallint) AS MissingDistrict
		--,FirstDistrict AS RangeMin
		--,LastDistrict AS RangeMax
		,dg.Area
		,dg.Bureau
		,NULL AS DistrictShapeArea		-- NULL as it cannot be figured out
		,NULL AS DistrictShapeLength	-- NULL as it cannot be figured out
	FROM [Crime].[CrimesFact] cf
	LEFT JOIN #Temp_DimDistricts td
		ON CAST(cf.District AS smallint) = td.District
	LEFT JOIN district_groups dg
		ON CAST(cf.District AS smallint) BETWEEN FirstDistrict AND LastDistrict
	WHERE td.District IS NULL 
	GROUP BY 
		CAST(cf.District AS smallint)
		,dg.Area
		,dg.Bureau
	
	UNION ALL -- stack missing and non missing districts in the same set
	
	SELECT * 
	FROM #Temp_DimDistricts
)
INSERT INTO [Location].[District] -- insert into the District table
	SELECT * 
	FROM all_districts
GO

-- 9) ENSURE A FULL MATCH BETWEEN THE DISTRICT FOREIGN KEY AND THE DISTRICT PRIMARY KEY

-- This step allows to join CrimesFact and Location.District through INNER JOIN with no data loss, that is, no LEFT JOIN is required.
-- The result involves more efficient queries on both the DWH and Power BI.

-- To realize it is necessary to assign an arbitrary value (like 0) to NULL districts and insert into the dimension table accordingly.

INSERT INTO [Location].[District] (District) VALUES (0)
GO

UPDATE [Crime].[CrimesFact]
SET District = 0
WHERE District IS NULL
GO

-- 10) CREATE A FUNCTION InitCap TO UPDATE CHARACTER STRINGS AND MAKE LOWERCASE ALL LETTERS BUT THE FIRST ONE.

IF OBJECT_ID(N'InitCap') IS NOT NULL
DROP FUNCTION [dbo].[InitCap]
GO
CREATE FUNCTION [dbo].[InitCap] ( @InputString varchar(41) ) 
RETURNS VARCHAR(4000)
AS
BEGIN

DECLARE @Index          INT
DECLARE @Char           CHAR(1)
DECLARE @PrevChar       CHAR(1)
DECLARE @OutputString   VARCHAR(255)

SET @OutputString = LOWER(@InputString)
SET @Index = 1

WHILE @Index <= LEN(@InputString) -- apply the below function on all the characters within the string
BEGIN
    SET @Char     = SUBSTRING(@InputString, @Index, 45) -- extract the character pointed by the index
    SET @PrevChar = CASE WHEN @Index = 1 THEN '' -- extract the first previous character and set it @PrevChar
                         ELSE SUBSTRING(@InputString, @Index - 1, 1)
                    END

    IF @PrevChar IN (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&', '''', '(') -- all the possible separators
    BEGIN
        IF @PrevChar != ''''
            SET @OutputString = STUFF(@OutputString, @Index, 1, UPPER(@Char))
    END
    SET @Index = @Index + 1 -- set the index to the next character (in order to repeat the function up to last one)
END
RETURN @OutputString

END
GO

-- 11) Apply the InitCap function to Bureau in the district table.

UPDATE [Location].[District]
SET Bureau = dbo.InitCap(Bureau)
GO

-- 12) CREATE THE DIMENSION TABLE Crime

IF OBJECT_ID(N'[Crime].CrimesDim') IS NOT NULL
DROP TABLE [Crime].CrimesDim
GO
CREATE TABLE [Crime].CrimesDim (
	Crime smallint PRIMARY KEY
	,CrimeName varchar(48) NOT NULL
)
GO

-- 13) AN INCONSISTENCY IN THE CRIME DESCRIPTION MUST BE FIXED BEFORE FILLING THE TABLE.

-- You can check the anomaly with the following script:

SELECT [Crm Cd], [Crm Cd Desc]
FROM [dbo].[Crime_Data_from_2010_to_2019]
WHERE [Crm Cd] = 522
GROUP BY [Crm Cd], [Crm Cd Desc]
UNION
SELECT [Crm Cd], [Crm Cd Desc]
FROM [dbo].[Crime_Data_from_2020_to_Present]
WHERE [Crm Cd] = 522
GROUP BY [Crm Cd], [Crm Cd Desc] 

-- 14) Update the description to ensure consistency and then fill the dimension table.

UPDATE [Crime].[CrimesFact]
SET [CrimeName] = 'VEHICLE, STOLEN - OTHER (MOTORIZED SCOOTERS, BIKES, ETC)'
WHERE [MainCrime] = 522
GO

INSERT INTO Crime.CrimesDim
	SELECT 
		[MainCrime]
		,[CrimeName]
	FROM [Crime].[CrimesFact]
	GROUP BY 
		[MainCrime]
		,[CrimeName]
GO

-- 15) APPLY THE InitCap FUNCTION TO CrimeName.

UPDATE Crime.CrimesDim
SET CrimeName = dbo.InitCap(CrimeName)
GO

-- 16) CREATE THE DIMENSION TABLE Ethnicity.

IF OBJECT_ID(N'Victim.Ethnicity') IS NOT NULL
DROP TABLE [Victim].[Ethnicity]
GO
CREATE TABLE Victim.Ethnicity (
	VictimEthnicity char(53) PRIMARY KEY
	,EthnicityDescription varchar(54) NOT NULL
)
GO

-- 17) INSERT THE ETHNICITY INTO THE TABLE.

WITH ethnicity_values AS (
	SELECT [VictimEthnicity]
	FROM [Crime].[CrimesFact]
	GROUP BY [VictimEthnicity]
)
INSERT INTO Victim.Ethnicity
	SELECT
		[VictimEthnicity]
		,CASE [VictimEthnicity]
			WHEN 'A' THEN 'Asian (Other)'
			WHEN 'B' THEN 'Black'
			WHEN 'C' THEN 'Chinese'
			WHEN 'D' THEN 'Cambodian'
			WHEN 'F' THEN 'Filipino'
			WHEN 'G' THEN 'Guamanian'
			WHEN 'H' THEN 'Hispanic/Latino/Mexican'
			WHEN 'I' THEN 'American Indian/Alaskan Native'
			WHEN 'J' THEN 'Japanese'
			WHEN 'K' THEN 'Korean'
			WHEN 'L' THEN 'Laotian'
			WHEN 'N' THEN 'Non-Hispanic/Non-Latino'
			WHEN 'O' THEN 'Other'
			WHEN 'P' THEN 'Pacific Islander'
			WHEN 'S' THEN 'Samoan'
			WHEN 'U' THEN 'Hawaiian'
			WHEN 'V' THEN 'Vietnamese'
			WHEN 'W' THEN 'White'
			WHEN 'Z' THEN 'Asian Indian'
			ELSE 'Unknown' -- refers to NULL or incorrect values
		 END AS [Description]
	FROM ethnicity_values
	WHERE 
		[VictimEthnicity] <> '-' 
		AND [VictimEthnicity] IS NOT NULL
	ORDER BY [VictimEthnicity]
GO

-- 18) UPDATE THE ETHNICITY IN THE FACT TABLE TO REPLACE NULL WITH "X".

UPDATE [Crime].[CrimesFact]
SET VictimEthnicity = 'X'
FROM [Crime].[CrimesFact] cf
LEFT JOIN [Victim].[Ethnicity] e 
	ON cf.VictimEthnicity = e.VictimEthnicity
WHERE e.VictimEthnicity IS NULL
GO

-- 19) SWITCH THE VICTIM AGE SIGN TO POSITIVE WHERE IT IS REPORTED AS NEGATIVE VALUE.

UPDATE [Crime].[CrimesFact]
SET [VictimAge] = ABS([VictimAge])
WHERE [VictimAge] < 0
GO

-- 20) SET THE AGE TO NULL WHERE IT IS EQUAL TO 0.

UPDATE [Crime].[CrimesFact]
SET [VictimAge] = NULL
WHERE [VictimAge] = 0
GO

-- 21) CREATE THE DIMENSION TABLE Sex.

IF OBJECT_ID(N'Victim.Sex') IS NOT NULL
DROP TABLE Victim.Sex
GO
CREATE TABLE Victim.Sex (
	VictimSex char(60) PRIMARY KEY
	,SexDescription varchar(685) NOT NULL
)
GO

-- 22) INSERT SEX VALUES.

WITH sex_values AS (
	SELECT [VictimSex]
	FROM [Crime].[CrimesFact]
	WHERE [VictimSex] IS NOT NULL
	GROUP BY [VictimSex]
)
INSERT INTO Victim.Sex
	SELECT DISTINCT
		CASE 
			WHEN [VictimSex] NOT IN ('M','F') THEN 'X'
			ELSE [VictimSex] 
		END AS Sex
		,CASE 
			WHEN [VictimSex] = 'M' THEN 'Male'
			WHEN [VictimSex] = 'F' THEN 'Female'
			ELSE 'Unknown' 
		END AS Description
	FROM sex_values
GO

-- 23) UPDATE THE FACT TABLE ACCORDINGLY.

UPDATE [Crime].[CrimesFact]
SET VictimSex = 'X'
FROM [Crime].[CrimesFact] cf
LEFT JOIN [Victim].[Sex] s ON cf.VictimSex = s.VictimSex
WHERE s.VictimSex IS NULL
GO

-- 24) CREATE THE DIMENSION TABLE LocationType.

IF OBJECT_ID(N'Location.LocationType') IS NOT NULL
DROP TABLE Location.LocationType
GO
CREATE TABLE [Location].[LocationType] (
	[LocationType] smallint PRIMARY KEY
	,LocTypeDescription varchar(65) NOT NULL
)
GO

-- 25) INSERT LOCATION TYPES.

WITH location_type_values AS (
	SELECT 
		CASE 
			WHEN [LocationTypeName] IS NULL THEN 0 -- 0 represents the unknown location type
			ELSE [LocationType] 
		END AS [LocationType]
		,CASE 
			WHEN [LocationTypeName] IS NULL THEN 'Unknown'
			ELSE [LocationTypeName] 
		 END AS [LocationTypeName]
	FROM [Crime].[CrimesFact]
)
INSERT INTO [Location].[LocationType]
	SELECT 
		[LocationType], 
		[LocationTypeName]
	FROM location_type_values
	GROUP BY 
		[LocationType], 
		[LocationTypeName]
	ORDER BY [LocationType]
GO

-- 26) APPLY THE InitCap FUNCTION TO LocTypeDescription.

UPDATE [Location].[LocationType]
SET [LocTypeDescription] = dbo.InitCap([LocTypeDescription])
GO

-- 27) UPDATE LocationType IN THE FACT TABLE TO REPLACE NULL WITH 0.

UPDATE [Crime].[CrimesFact]
SET [LocationType] = 0
WHERE [LocationTypeName] IS NULL
GO

-- 28) CREATE THE DIMENSION TABLE Weapon.

IF OBJECT_ID(N'Weapon.Weapon') IS NOT NULL
DROP TABLE Weapon.Weapon
GO
CREATE TABLE Weapon.Weapon (
	Weapon smallint PRIMARY KEY
	,WeaponDescription varchar(70) NOT NULL
)
GO

-- 29) INSERT INTO THE TABLE.

WITH weapon_values AS (
	SELECT 
		CASE 
			WHEN [WeaponName] IS NULL THEN 0 -- represents the unknown weapons
			ELSE [Weapon] 
		END AS [Weapon]
		,CASE 
			WHEN [WeaponName] IS NULL THEN 'Unknown'
			ELSE [WeaponName] 
		 END AS [WeaponName]
	FROM [Crime].[CrimesFact]
)
INSERT INTO Weapon.Weapon
	SELECT 
		[Weapon], 
		[WeaponName]
	FROM weapon_values
	GROUP BY 
		[Weapon], 
		[WeaponName]
GO

-- 30) APPLY THE InitiCap FUNCTION TO WeaponDescription.

UPDATE [Weapon].[Weapon]
SET [WeaponDescription] = dbo.InitCap([WeaponDescription])
GO

-- 31) UPDATE THE FACT TABLE TO UPDATE Weapon AND REPLACE NULL WITH 0.

UPDATE [Crime].[CrimesFact]
SET [Weapon] = 0
WHERE [WeaponName] IS NULL
GO

-- 32) CREATE THE DIMENSION TABLE InvestigationStatus.

IF OBJECT_ID(N'Crime.InvestigationStatus') IS NOT NULL
DROP TABLE Crime.InvestigationStatus
GO
CREATE TABLE Crime.InvestigationStatus (
	[Status] tinyint PRIMARY KEY
	,StatusName varchar(75) NOT NULL
	,PersonType varchar(20)
)
GO

-- 33) INSERT INVESTIGATION STATUS VALUES INTO THE TABLE.

WITH status_groups AS (
	SELECT 
		CASE [Status] 
			WHEN 'AA' THEN 1
			WHEN 'JA' THEN 2
			WHEN 'AO' THEN 3
			WHEN 'JO' THEN 4
			WHEN 'IC' THEN 5
			ELSE 6
		END AS [Status]
		,CASE [Status] 
			WHEN 'AA' THEN 'Arrest'
			WHEN 'JA' THEN 'Arrest'
			WHEN 'AO' THEN 'No Arrest'
			WHEN 'JO' THEN 'No Arrest'
			WHEN 'IC' THEN 'Investigation'
			ELSE 'Unknown'
		 END AS StatusName
		,CASE [Status] 
			WHEN 'AA' THEN 'Adult'
			WHEN 'JA' THEN 'Juvenile'
			WHEN 'AO' THEN 'Adult'
			WHEN 'JO' THEN 'Juvenile'
			ELSE NULL
		 END AS PersonType
	FROM [Crime].[CrimesFact]
)
INSERT INTO Crime.InvestigationStatus
	SELECT *
	FROM status_groups
	GROUP BY 
		[Status], 
		StatusName, 
		PersonType
	ORDER BY [Status]
GO

-- 34) UPDATE THE CrimesFact TABLE ACCORDINGLY.

UPDATE [Crime].[CrimesFact]
SET [Status] = CASE [Status] 
				WHEN 'AA' THEN 1
				WHEN 'JA' THEN 2
				WHEN 'AO' THEN 3
				WHEN 'JO' THEN 4
				WHEN 'IC' THEN 5
				ELSE 6
			   END
GO

-- 35) CREATE THE FUNCTION RemoveMultipleSpaces TO REMOVE UNNECESSARY SPACE CHARACTERS.

IF OBJECT_ID(N'RemoveMultipleSpaces') IS NOT NULL
DROP FUNCTION dbo.RemoveMultipleSpaces
GO
CREATE FUNCTION [dbo].[RemoveMultipleSpaces] (@inputString nvarchar(max))
RETURNS nvarchar(max)
AS
BEGIN
    DECLARE @cleanedString NVARCHAR(MAX) = @inputString
    WHILE CHARINDEX('  ', @cleanedString) > 0
    BEGIN
        SET @cleanedString = REPLACE(@cleanedString, '  ', ' ');
    END
    SET @cleanedString = LTRIM(RTRIM(@cleanedString))
    RETURN @cleanedString;
END
GO

-- 36) APPLY THE FUNCTIONS RemoveMultipleSpaces AND InitCap TO RoundedStreet AND CrossStreet.

UPDATE [Crime].[CrimesFact]
SET RoundedStreet = dbo.RemoveMultipleSpaces(dbo.InitCap(RoundedStreet))
GO

UPDATE [Crime].[CrimesFact]
SET CrossStreet = dbo.RemoveMultipleSpaces(dbo.InitCap(CrossStreet))
GO

-- 37) SET Latitude AND Longitude TO NULL WHERE THEY ARE EQUAL TO 0.

UPDATE [Crime].[CrimesFact]
SET Latitude = NULL
WHERE Latitude = '0'
GO

UPDATE [Crime].[CrimesFact]
SET Longitude = NULL
WHERE Longitude = '0'
GO

-- 38) DROP USELESS COLUMNS FROM THE FACT TABLE.

ALTER TABLE [Crime].[CrimesFact]
DROP COLUMN
	[Area]
	,[AreaName]
	,[CrimeName]
	,[LocationTypeName]
	,[WeaponName]
	,[StatusName]
GO

-- 39) SET THE APPROPRIATAE DATA TYPES.

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [ReportDate] date NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [District] smallint NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [MainCrime] smallint NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [VictimAge] tinyint NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [VictimSex] char(86) NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [VictimEthnicity] char(1) NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [LocationType] smallint NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [Weapon] smallint NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [Status] tinyint NOT NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [RoundedStreet] varchar(87) NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [CrossStreet] varchar(88) NULL

ALTER TABLE [Crime].[CrimesFact]
ALTER COLUMN [Latitude] real NULL

ALTER TABLE [Crime].[CrimesFact]
	ALTER COLUMN [Longitude] real NULL
GO

-- 40) CREATE THE CONSTRAINTS TO SET DEFAULT VALUES ON COLUMN THAT WILL BEHAVE AS FOREIGN KEYS.

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ((0)) FOR [District]
GO

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ('X') FOR [VictimSex]
GO

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ('X') FOR [VictimEthnicity]
GO

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ((0)) FOR [LocationType]
GO

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ((0)) FOR [Weapon]
GO

ALTER TABLE [Crime].[CrimesFact] 
ADD  DEFAULT ((6)) FOR [Status]
GO


-- 41) CREATE THE FOREIGN KEYS TO LINK THE CrimesFact TABLE TO THE DIMENSION TABLES.

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_Crime FOREIGN KEY (MainCrime) 
	REFERENCES [Crime].[CrimesDim] (Crime)
	ON UPDATE CASCADE
	ON DELETE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_District FOREIGN KEY (District) 
	REFERENCES [Location].[District] (District)
	ON UPDATE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_VictimSex FOREIGN KEY (VictimSex) 
	REFERENCES [Victim].[Sex] (VictimSex)
	ON UPDATE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_VictimEthnicity FOREIGN KEY (VictimEthnicity) 
	REFERENCES [Victim].[Ethnicity] (VictimEthnicity)
	ON UPDATE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_LocationType FOREIGN KEY (LocationType) 
	REFERENCES [Location].[LocationType] (LocationType)
	ON UPDATE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_Weapon FOREIGN KEY (Weapon) 
	REFERENCES [Weapon].[Weapon] (Weapon)
	ON UPDATE CASCADE
GO

ALTER TABLE [Crime].[CrimesFact]
	ADD CONSTRAINT FK_Status FOREIGN KEY (Status) 
	REFERENCES [Crime].[InvestigationStatus] (Status)
	ON UPDATE CASCADE
GO

-- 42) ADD A TIMESTAMP COLUMN TO SHOW WHEN DATA WAS INSERTED.

ALTER TABLE [Crime].[CrimesFact]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Crime].[CrimesDim]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Crime].[InvestigationStatus]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Location].[District]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Location].[LocationType]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Victim].[Ethnicity]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Victim].[Sex]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
ALTER TABLE [Weapon].[Weapon]
	ADD [Timestamp] datetime NOT NULL DEFAULT current_timestamp
GO

