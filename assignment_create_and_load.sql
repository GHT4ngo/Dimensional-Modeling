-- ============================================================
--  Assignment_Create_And_Load.sql
--
--  Creates a Star Schema with 2 fact tables
--  all dimensions, indexes, FK constraints, and loads
--  data from TestDataDB.
--
--  Run TestDB_Create_And_Seed.sql before this to create a 
--  data base with test data.
--
--  Engine : SQL Server 2019+ / SSMS
--  Author : Christofer Lindholm
--  Date   : 2026-03-31
-- ============================================================


-- ------------------------------------------------------------
--  1. DATABASE
-- ------------------------------------------------------------
USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DDNews')
BEGIN
    ALTER DATABASE DDNews SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DDNews;
END
GO

CREATE DATABASE DDNews
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE DDNews;
GO


-- ------------------------------------------------------------
--  2. DIMENSION TABLES
-- ------------------------------------------------------------

-- Create DimDate Table  (SCD Type 0 — static, pre-populated)
CREATE TABLE DimDate (
    DateID          INT             NOT NULL  -- Primary key format: YYYYMMDD
    ,[Year]         INT             NOT NULL
    ,[Month]        INT             NOT NULL
    ,[Day]          INT             NOT NULL
    ,[Week]         INT             NOT NULL
    ,[MonthName]    VARCHAR(20)     NOT NULL
    ,WeekName       VARCHAR(20)     NOT NULL
    ,[Quarter]      INT             NOT NULL

    ,CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateID)
);
GO

-- Create DimAction Table  (SCD Type 0 — static lookup)
CREATE TABLE DimAction (
    ActionSK        INT             NOT NULL    IDENTITY(1,1)
    ,[Action]       VARCHAR(20)     NOT NULL
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 1

    ,CONSTRAINT PK_DimAction        PRIMARY KEY CLUSTERED (ActionSK)
);
GO

-- Create DimCategory Table  (SCD Type 1 — overwrite on change)
CREATE TABLE DimCategory (
    CategorySK      INT             NOT NULL    IDENTITY(1,1)
    ,CategoryID     INT             NOT NULL  
    ,Category       VARCHAR(30)     NOT NULL
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 1

    ,CONSTRAINT PK_DimCategory      PRIMARY KEY CLUSTERED (CategorySK)
);
GO

-- Create DimTag Table  (SCD Type 1 — overwrite on change)
CREATE TABLE DimTag (
    TagSK           INT             NOT NULL    IDENTITY(1,1)
    ,TagID          INT             NOT NULL
    ,Tag            VARCHAR(30)     NOT NULL
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 1
    
    ,CONSTRAINT PK_DimTag           PRIMARY KEY CLUSTERED (TagSK)
);
GO

-- DimArticle  (SCD Type 1 — overwrite on change)
CREATE TABLE DimArticle (
    ArticleSK       INT             NOT NULL    IDENTITY(1,1)
    ,ArticleID      INT             NOT NULL 
    ,Title          VARCHAR(255)    NOT NULL
    ,Content        VARCHAR(MAX)    NOT NULL
    ,[Status]       SMALLINT        NOT NULL
    ,SecurityLevel  TINYINT         NOT NULL

    ,CONSTRAINT PK_DimArticle       PRIMARY KEY CLUSTERED (ArticleSK)
);
GO

-- Create DimUser Table (SCD Type 2 — full history tracked)
CREATE TABLE DimUser (
    UserSK          INT             NOT NULL    IDENTITY(1,1)
    ,UserID         INT             NOT NULL   
    ,FirstName      VARCHAR(50)     NOT NULL 
    ,LastName       VARCHAR(50)     NOT NULL 
    ,Email          VARCHAR(100)    NOT NULL 
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 0
    ,ValidFrom      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,ValidTo        DATETIME2       NULL        DEFAULT NULL
    ,IsCurrent      BIT             NOT NULL    DEFAULT 1
    ,CreatedBy      VARCHAR(50)     NOT NULL 
    ,ChangeReason   VARCHAR(255)    NULL
    
    ,CONSTRAINT PK_DimUser          PRIMARY KEY CLUSTERED (UserSK)
);
GO

-- Create DimDepartment Table  (SCD Type 2 — full history tracked)
CREATE TABLE DimDepartment (
    DepartmentSK    INT             NOT NULL    IDENTITY(1,1)
    ,DepartmentID   INT             NOT NULL
    ,Department     VARCHAR(30)     NOT NULL
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 1
    ,ValidFrom      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,ValidTo        DATETIME2       NULL        DEFAULT NULL
    ,IsCurrent      BIT             NOT NULL    DEFAULT 1
    ,CreatedBy      VARCHAR(50)     NOT NULL
    ,ChangeReason   VARCHAR(255)    NULL

    ,CONSTRAINT PK_DimDepartment    PRIMARY KEY CLUSTERED (DepartmentSK)
);
GO

-- Create FactAuditLog Table (central fact table — editorial workflow process)
CREATE TABLE FactAuditLog (
    LogID               INT         NOT NULL 
    ,UserSK             INT         NOT NULL
    ,ArticleSK          INT         NOT NULL
    ,ActionSK           INT         NOT NULL
    ,CategorySK         INT         NULL      
    ,TagSK              INT         NULL     
    ,DepartmentSK       INT         NOT NULL
    ,DateID             INT         NOT NULL
    -- Measures
    ,ProcessTime        INT         NULL                    -- seconds from article creation to this event  (Additive)
    ,IsEscalated        BIT         NOT NULL    DEFAULT 0   -- security mismatch flag                       (Semi-additive)
    ,ArticleWordCount   INT         NULL                    -- word count at time of event                  (Non-additive)

    ,CONSTRAINT PK_FactAuditLog     PRIMARY KEY CLUSTERED (LogID)
);
GO

-- FactArticleView  (readership process — different grain from FactAuditLog)
-- Captures who read which article and for how long.
-- Anonymous/external viewers resolve to the DimUser sentinel row (UserSK = -1),
-- so all FKs are NOT NULL — no nullable foreign keys needed.
CREATE TABLE FactArticleView (
    ViewID          INT             NOT NULL
    ,UserSK         INT             NOT NULL   -- -1 = Anonymous sentinel
    ,ArticleSK      INT             NOT NULL
    ,DepartmentSK   INT             NOT NULL   -- -1 = Unknown sentinel
    ,DateID         INT             NOT NULL
    -- Measures
    ,ViewDuration   INT             NULL                    -- seconds spent reading (Additive)
    ,IsAnonymous    BIT             NOT NULL    DEFAULT 0   -- 1 = no login / no clearance (Semi-additive)
    ,SecurityLevel  TINYINT         NOT NULL    DEFAULT 0   -- reader's level at read time (Non-additive); 0 = anonymous

    ,CONSTRAINT PK_FactArticleView  PRIMARY KEY CLUSTERED (ViewID)
);
GO


-- ------------------------------------------------------------
--  3. FOREIGN KEYS
-- ------------------------------------------------------------

-- Create constraints in FactAuditLog to enforce referential integrity in the database
ALTER TABLE FactAuditLog
    ADD CONSTRAINT FK_Fact_User         FOREIGN KEY (UserSK)        REFERENCES DimUser(UserSK),
        CONSTRAINT FK_Fact_Article      FOREIGN KEY (ArticleSK)     REFERENCES DimArticle(ArticleSK),
        CONSTRAINT FK_Fact_Action       FOREIGN KEY (ActionSK)      REFERENCES DimAction(ActionSK),
        CONSTRAINT FK_Fact_Category     FOREIGN KEY (CategorySK)    REFERENCES DimCategory(CategorySK),
        CONSTRAINT FK_Fact_Tag          FOREIGN KEY (TagSK)         REFERENCES DimTag(TagSK),
        CONSTRAINT FK_Fact_Department   FOREIGN KEY (DepartmentSK)  REFERENCES DimDepartment(DepartmentSK),
        CONSTRAINT FK_Fact_Date         FOREIGN KEY (DateID)        REFERENCES DimDate(DateID);
GO

-- Create constraints in FactArticleView to enforce referential integrity in the database
ALTER TABLE FactArticleView
    ADD CONSTRAINT FK_View_User         FOREIGN KEY (UserSK)        REFERENCES DimUser(UserSK),
        CONSTRAINT FK_View_Article      FOREIGN KEY (ArticleSK)     REFERENCES DimArticle(ArticleSK),
        CONSTRAINT FK_View_Department   FOREIGN KEY (DepartmentSK)  REFERENCES DimDepartment(DepartmentSK),
        CONSTRAINT FK_View_Date         FOREIGN KEY (DateID)        REFERENCES DimDate(DateID);
GO


-- ------------------------------------------------------------
--  4. INDEXES
-- ------------------------------------------------------------

-- Dimension natural key lookups
CREATE NONCLUSTERED INDEX idx_DimUser_UserID            ON DimUser          (UserID, IsCurrent);
CREATE NONCLUSTERED INDEX idx_DimDept_DepartmentID      ON DimDepartment    (DepartmentID, IsCurrent);
CREATE NONCLUSTERED INDEX idx_DimArticle_ArticleID      ON DimArticle       (ArticleID);
CREATE NONCLUSTERED INDEX idx_DimCategory_CategoryID    ON DimCategory      (CategoryID);
CREATE NONCLUSTERED INDEX idx_DimTag_TagID              ON DimTag           (TagID);
CREATE NONCLUSTERED INDEX idx_DimAction_Action          ON DimAction        ([Action]);
                          
-- FactAuditLog indexes 
CREATE NONCLUSTERED INDEX idx_Fact_UserSK               ON FactAuditLog     (UserSK);
CREATE NONCLUSTERED INDEX idx_Fact_ArticleSK            ON FactAuditLog     (ArticleSK);
CREATE NONCLUSTERED INDEX idx_Fact_ActionSK             ON FactAuditLog     (ActionSK);
CREATE NONCLUSTERED INDEX idx_Fact_CategorySK           ON FactAuditLog     (CategorySK);
CREATE NONCLUSTERED INDEX idx_Fact_TagSK                ON FactAuditLog     (TagSK);
CREATE NONCLUSTERED INDEX idx_Fact_DepartmentSK         ON FactAuditLog     (DepartmentSK);
CREATE NONCLUSTERED INDEX idx_Fact_DateID               ON FactAuditLog     (DateID);
                          
-- FactArticleView indexes
CREATE NONCLUSTERED INDEX idx_View_UserSK               ON FactArticleView  (UserSK);
CREATE NONCLUSTERED INDEX idx_View_ArticleSK            ON FactArticleView  (ArticleSK);
CREATE NONCLUSTERED INDEX idx_View_DepartmentSK         ON FactArticleView  (DepartmentSK);
CREATE NONCLUSTERED INDEX idx_View_DateID               ON FactArticleView  (DateID);
GO                        


-- ============================================================
--  5. ETL — LOAD FROM TestDataDB
--
--  Each section loads one table in dependency order:
--  5.1 DimDate  
--  5.2 DimAction
--  5.3 DimCategory     (SCD Type 1)
--  5.4 DimTag          (SCD Type 1)
--  5.6 DimUser         (SCD Type 2)
--  5.7 DimDepartment   (SCD Type 2)
--
--  5.8 FactAuditLog
--  5.9 FactArticleView
--
-- ============================================================


-- ------------------------------------------------------------
--  5.1 DimDate  (2020-01-01 to 2030-12-31)
-- ------------------------------------------------------------
;WITH DateSeries AS (
    SELECT CAST('2020-01-01' AS DATE) AS [Date]
    UNION ALL
    SELECT DATEADD(DAY, 1, [Date])
    FROM   DateSeries
    WHERE  [Date] < '2030-12-31'
)
INSERT INTO DimDate (DateID, [Year], [Month], [Day], [Week], [MonthName], WeekName, [Quarter])
SELECT
    CAST(FORMAT([Date], 'yyyyMMdd') AS INT)     AS DateID
    ,YEAR([Date])                               AS [Year]
    ,MONTH([Date])                              AS [Month]
    ,DAY([Date])                                AS [Day]
    ,DATEPART(ISO_WEEK, [Date])                 AS [Week]
    ,DATENAME(MONTH, [Date])                    AS [MonthName]
    ,DATENAME(WEEKDAY, [Date])                  AS WeekName
    ,DATEPART(QUARTER, [Date])                  AS [Quarter]
FROM DateSeries 
OPTION (MAXRECURSION 0); 
GO


-- ------------------------------------------------------------
--  5.2 DimAction  
-- ------------------------------------------------------------

-- Ranks can be modified after preference
INSERT INTO DimAction ([Action], SecurityLevel)
SELECT DISTINCT
    al.[Action]
    ,CASE al.[Action]
        WHEN 'Draft'          THEN 1    -- Menig
        WHEN 'Submit'         THEN 1
        WHEN 'Review'         THEN 3    -- Sergant
        WHEN 'Approve'        THEN 3
        WHEN 'Reject'         THEN 3
        WHEN 'RequestChange'  THEN 3
        WHEN 'Publish'        THEN 8    -- Kapten
        ELSE 1
    END AS SecurityLevel
FROM TestDataDB.dbo.AuditLog AS al;
GO


-- ------------------------------------------------------------
--  5.3 DimCategory  (SCD Type 1)
-- ------------------------------------------------------------
INSERT INTO DimCategory (CategoryID, Category, SecurityLevel)
SELECT
    CategoryID,
    [Name]      AS Category
    ,1           AS SecurityLevel
FROM TestDataDB.dbo.Category;
GO


-- ------------------------------------------------------------
--  5.4 DimTag  (SCD Type 1)
-- ------------------------------------------------------------
INSERT INTO DimTag (TagID, Tag, SecurityLevel)
SELECT
    TagID,
    [Name]      AS Tag
    ,1           AS SecurityLevel
FROM TestDataDB.dbo.Tag;
GO


-- ------------------------------------------------------------
--  5.5 DimArticle  (SCD Type 1)
-- ------------------------------------------------------------
INSERT INTO DimArticle (ArticleID, Title, Content, [Status], SecurityLevel)
SELECT
    ArticleID
    ,Title
    ,Content
    ,[Status]
    ,SecurityLevel
FROM TestDataDB.dbo.Article;
GO


-- ------------------------------------------------------------
--  5.6 DimUser  (SCD Type 2)
--
--  Row 1 is always the "Anonymous" sentinel (Unknown Member pattern).
--  All anonymous/external viewers in FactArticleView point here.
--  This row's attributes never change, so SCD Type 2 never triggers
--  for it, avoiding the problem of tracking external viewers.
-- ------------------------------------------------------------

-- Sentinel row for anonymous / external viewers (static, SCD Type 0 in practice)
SET IDENTITY_INSERT DimUser ON;

INSERT INTO DimUser (UserSK, UserID, FirstName, LastName, Email, SecurityLevel,
                     ValidFrom, ValidTo, IsCurrent, CreatedBy, ChangeReason)

VALUES (
    -1
    ,-1
    ,'Anonymous'
    ,'Viewer'
    ,'N/A'
    ,0
    ,'2000-01-01'
    ,NULL
    ,1
    ,'ETL_Initial_Load'
    ,'Unknown member sentinel'
);

SET IDENTITY_INSERT DimUser OFF;
GO

-- Real internal users
INSERT INTO DimUser (UserID, FirstName, LastName, Email, SecurityLevel,
                     ValidFrom, ValidTo, IsCurrent, CreatedBy, ChangeReason)
SELECT
    u.UserID
    ,u.FirstName
    ,u.LastName
    ,u.Email
    ,sr.SecurityLevel
    ,GETDATE()                           AS ValidFrom
    ,NULL                                AS ValidTo
    ,1                                   AS IsCurrent
    ,'ETL_Initial_Load'                  AS CreatedBy
    ,'Initial load'                      AS ChangeReason
FROM TestDataDB.dbo.[User]               AS u
JOIN TestDataDB.dbo.SecurityRole         AS sr 
    ON u.RoleID = sr.RoleID;
GO


-- ------------------------------------------------------------
--  5.7 DimDepartment  (SCD Type 2)
-- ------------------------------------------------------------

-- Sentinel row for anonymous / external viewers
SET IDENTITY_INSERT DimDepartment ON;

INSERT INTO DimDepartment (DepartmentSK, DepartmentID, Department, SecurityLevel,
                            ValidFrom, ValidTo, IsCurrent, CreatedBy, ChangeReason)
VALUES (
    -1
    ,-1
    ,'Unknown'
    ,0
    ,'2000-01-01'
    ,NULL
    ,1
    ,'ETL_Initial_Load'
    ,'Unknown member sentinel'
);

SET IDENTITY_INSERT DimDepartment OFF;
GO

-- Real departments
INSERT INTO DimDepartment (DepartmentID, Department, SecurityLevel,
                            ValidFrom, ValidTo, IsCurrent, CreatedBy, ChangeReason)
SELECT
    DepartmentID
    ,[Name]             AS Department
    ,1                  AS SecurityLevel
    ,GETDATE()          AS ValidFrom
    ,NULL               AS ValidTo
    ,1                  AS IsCurrent
    ,'ETL_Initial_Load' AS CreatedBy
    ,'Initial load'     AS ChangeReason
FROM TestDataDB.dbo.Department;
GO


-- ------------------------------------------------------------
--  5.8 FactAuditLog
--
--  One row per AuditLog event.
--  Surrogate key lookups:
--    UserSK       — DimUser WHERE IsCurrent = 1
--    ArticleSK    — DimArticle
--    ActionSK     — DimAction
--    CategorySK   — DimCategory (from Article, nullable)
--    TagSK        — DimTag (from Article, nullable)
--    DepartmentSK — DimDepartment WHERE IsCurrent = 1 (via User)
--    DateID       — DimDate (from AuditLog.TimeStamp)
--
--  Measures:
--    ProcessTime       = seconds from Article.CreatedAt to this event
--    IsEscalated       = 1 when user SecurityLevel < article SecurityLevel
--    ArticleWordCount  = approximate word count of article content
-- ------------------------------------------------------------
INSERT INTO FactAuditLog (
    LogID, UserSK, ArticleSK, ActionSK, CategorySK, TagSK,
    DepartmentSK, DateID, ProcessTime, IsEscalated, ArticleWordCount
)
SELECT
    al.LogID
    ,du.UserSK
    ,da.ArticleSK
    ,dact.ActionSK
    ,dc.CategorySK
    ,dt.TagSK
    ,dd.DepartmentSK
    ,CAST(FORMAT(al.[TimeStamp], 'yyyyMMdd') AS INT)             AS DateID

    ,DATEDIFF(SECOND, art.CreatedAt, al.[TimeStamp])             AS ProcessTime
    ,CASE WHEN sr.SecurityLevel < art.SecurityLevel THEN 1 
        ELSE 0 END                                               AS IsEscalated
    ,(LEN(art.Content) - LEN(REPLACE(art.Content, ' ', '')) + 1) AS ArticleWordCount

FROM TestDataDB.dbo.AuditLog               AS al

-- Source tables
JOIN TestDataDB.dbo.Article                AS art  ON al.ArticleID     = art.ArticleID
JOIN TestDataDB.dbo.[User]                 AS u    ON al.UserID        = u.UserID
JOIN TestDataDB.dbo.SecurityRole           AS sr   ON u.RoleID         = sr.RoleID

-- Dimension surrogate key lookups
JOIN DimUser                               AS du   ON u.UserID         = du.UserID
                                                  AND du.IsCurrent     = 1
JOIN DimArticle                            AS da   ON art.ArticleID    = da.ArticleID
JOIN DimAction                             AS dact ON al.Action        = dact.Action
JOIN DimDepartment                         AS dd   ON u.DepartmentID   = dd.DepartmentID
                                                  AND dd.IsCurrent     = 1
LEFT JOIN DimCategory                      AS dc   ON art.CategoryID   = dc.CategoryID
LEFT JOIN DimTag                           AS dt   ON art.TagID        = dt.TagID;
GO


-- ------------------------------------------------------------
--  5.9 FactArticleView
--
--  One row per ViewLog event.
--  Surrogate key lookups:
--    UserSK       — DimUser WHERE IsCurrent = 1; falls back to sentinel (-1) for anonymous
--    ArticleSK    — DimArticle
--    DepartmentSK — DimDepartment WHERE IsCurrent = 1; falls back to sentinel (-1) for anonymous
--    DateID       — DimDate (from ViewLog.TimeStamp)
--
--  Anonymous/external viewers map to the sentinel row (UserSK = -1, DepartmentSK = -1).
--  This avoids NULL foreign keys and means SCD Type 2 is never triggered for
--  external viewers — the sentinel row's attributes never change.
--
--  Measures:
--    ViewDuration  = seconds from ViewLog.Duration (direct)
--    IsAnonymous   = 1 when ViewLog.UserID IS NULL
--    SecurityLevel = reader's SecurityLevel; 0 if anonymous
-- ------------------------------------------------------------
INSERT INTO FactArticleView (
    ViewID, UserSK, ArticleSK, DepartmentSK, DateID,
    ViewDuration, IsAnonymous, SecurityLevel
)
SELECT
    vl.ViewID
    ,ISNULL(du.UserSK,  -1)                              AS UserSK        -- -1 = Anonymous sentinel
    ,da.ArticleSK
    ,ISNULL(dd.DepartmentSK, -1)                         AS DepartmentSK  -- -1 = Unknown sentinel
    ,CAST(FORMAT(vl.[TimeStamp], 'yyyyMMdd') AS INT)     AS DateID

    ,vl.Duration                                         AS ViewDuration
    ,CASE WHEN vl.UserID IS NULL THEN 1 ELSE 0 END       AS IsAnonymous
    ,ISNULL(CAST(sr.SecurityLevel AS TINYINT), 0)        AS SecurityLevel

FROM TestDataDB.dbo.ViewLog                 AS vl

-- Source tables (left joins because UserID can be NULL for anonymous readers)
JOIN      TestDataDB.dbo.Article            AS art  ON vl.ArticleID     = art.ArticleID
LEFT JOIN TestDataDB.dbo.[User]             AS u    ON vl.UserID        = u.UserID
LEFT JOIN TestDataDB.dbo.SecurityRole       AS sr   ON u.RoleID         = sr.RoleID

-- Dimension lookups — left joins so anonymous rows resolve to ISNULL fallback above
LEFT JOIN DimUser                           AS du   ON u.UserID         = du.UserID
                                                   AND du.IsCurrent     = 1
JOIN      DimArticle                        AS da   ON art.ArticleID    = da.ArticleID
LEFT JOIN DimDepartment                     AS dd   ON u.DepartmentID   = dd.DepartmentID
                                                   AND dd.IsCurrent     = 1;
GO


-- ============================================================
--  6. QUICK VERIFICATION
-- ============================================================
SELECT 'DimDate'            AS [Table], COUNT(*) AS [Rows] FROM DimDate
UNION ALL SELECT 'DimAction',           COUNT(*) FROM DimAction
UNION ALL SELECT 'DimCategory',         COUNT(*) FROM DimCategory
UNION ALL SELECT 'DimTag',              COUNT(*) FROM DimTag
UNION ALL SELECT 'DimArticle',          COUNT(*) FROM DimArticle
UNION ALL SELECT 'DimUser',             COUNT(*) FROM DimUser
UNION ALL SELECT 'DimDepartment',       COUNT(*) FROM DimDepartment
UNION ALL SELECT 'FactAuditLog',        COUNT(*) FROM FactAuditLog
UNION ALL SELECT 'FactArticleView',     COUNT(*) FROM FactArticleView;
GO

-- Sample 1: average process time per department and action (workflow)
SELECT
    dd.Department
    ,dact.Action
    ,COUNT(*)                            AS EventCount
    ,AVG(f.ProcessTime)                  AS AvgProcessTimeSec
    ,SUM(CAST(f.IsEscalated AS INT))     AS EscalatedEvents
FROM FactAuditLog           AS f
JOIN DimDepartment          AS dd   ON f.DepartmentSK   = dd.DepartmentSK
JOIN DimAction              AS dact ON f.ActionSK        = dact.ActionSK
GROUP BY dd.Department, dact.Action
ORDER BY dd.Department, dact.Action;
GO

-- Sample 2: readership per article — total views, anonymous vs authenticated
SELECT
    da.Title
    ,COUNT(*)                                AS TotalViews
    ,SUM(CAST(fv.IsAnonymous AS INT))        AS AnonymousViews
    ,SUM(CAST(1 - fv.IsAnonymous AS INT))    AS AuthenticatedViews
    ,AVG(fv.ViewDuration)                    AS AvgDurationSec
FROM FactArticleView        AS fv
JOIN DimArticle             AS da   ON fv.ArticleSK = da.ArticleSK
GROUP BY da.Title
ORDER BY TotalViews DESC;
GO
