-- ============================================================
--  TestDB_Create_And_Seed.sql
--
--  Run before Assignment_Create_And_Load.sql
--
--  Creates the source database, all tables, indexes,
--  constraints and seeds realistic test data matching the
--  ER diagram made for "Försvarsmaktens Nyhetssystem"
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

-- Drop TestDataDB if it exists
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'TestDataDB')
BEGIN
    ALTER DATABASE TestDataDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TestDataDB;
END
GO

-- Create TestDataDB
CREATE DATABASE TestDataDB
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

-- Use TestDataDB
USE TestDataDB;
GO


-- ------------------------------------------------------------
--  2. TABLES
-- ------------------------------------------------------------

-- Create Department Table
CREATE TABLE Department (
    DepartmentID    INT             NOT NULL    IDENTITY(1,1)
    ,Name           VARCHAR(50)     NOT NULL
    
    ,CONSTRAINT PK_Department       PRIMARY KEY CLUSTERED   (DepartmentID)
);
GO

-- Create SecurityRole Table
CREATE TABLE SecurityRole (
    RoleID          INT             NOT NULL    IDENTITY(1,1)
    ,RoleName       VARCHAR(25)     NOT NULL
    ,SecurityLevel  SMALLINT        NOT NULL

    ,CONSTRAINT PK_SecurityRole     PRIMARY KEY CLUSTERED   (RoleID)
);
GO

-- Create User Table
CREATE TABLE [User] (
    UserID          INT             NOT NULL    IDENTITY(1,1)
    ,FirstName      VARCHAR(50)     NOT NULL
    ,LastName       VARCHAR(50)     NOT NULL
    ,Email          VARCHAR(100)    NOT NULL
    ,DepartmentID   INT             NOT NULL
    ,RoleID         INT             NOT NULL

    ,CONSTRAINT PK_User             PRIMARY KEY CLUSTERED   (UserID)
    ,CONSTRAINT FK_User_Dept        FOREIGN KEY             (DepartmentID)  REFERENCES Department(DepartmentID)
    ,CONSTRAINT FK_User_Role        FOREIGN KEY             (RoleID)        REFERENCES SecurityRole(RoleID)
    ,CONSTRAINT UQ_User_Email       UNIQUE                  (Email)
);
GO

-- Create Category Table
CREATE TABLE Category (
    CategoryID      INT             NOT NULL    IDENTITY(1,1)
    ,Name           VARCHAR(25)     NOT NULL
    
    ,CONSTRAINT PK_Category         PRIMARY KEY CLUSTERED   (CategoryID)
);
GO

-- Create Tag Table
CREATE TABLE Tag (
    TagID           INT             NOT NULL    IDENTITY(1,1)
    ,Name           VARCHAR(25)     NOT NULL

    ,CONSTRAINT PK_Tag PRIMARY KEY CLUSTERED (TagID)
);
GO

-- Create Article Table
-- Status: 0=Draft  1=Submitted  2=Approved  3=Rejected  4=ChangesRequested
CREATE TABLE Article (
    ArticleID       INT             NOT NULL    IDENTITY(1,1)
    ,Title          VARCHAR(255)    NOT NULL
    ,Content        VARCHAR(MAX)    NOT NULL
    ,[Status]       SMALLINT        NOT NULL    DEFAULT 0
    ,SecurityLevel  TINYINT        NOT NULL    DEFAULT 1
    ,CreatedAt      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,PublishedAt    DATETIME2       NULL
    ,CategoryID     INT             NOT NULL
    ,TagID          INT             NULL
    ,DepartmentID   INT             NOT NULL
    ,UserID         INT             NOT NULL

    ,CONSTRAINT PK_Article          PRIMARY KEY CLUSTERED       (ArticleID)
    ,CONSTRAINT FK_Article_Category FOREIGN KEY                 (CategoryID)    REFERENCES Category(CategoryID)
    ,CONSTRAINT FK_Article_Tag      FOREIGN KEY                 (TagID)         REFERENCES Tag(TagID)
    ,CONSTRAINT FK_Article_Dept     FOREIGN KEY                 (DepartmentID)  REFERENCES Department(DepartmentID)
    ,CONSTRAINT FK_Article_User     FOREIGN KEY                 (UserID)        REFERENCES [User](UserID)
    ,CONSTRAINT CK_Article_Status   CHECK (Status BETWEEN 0 AND 4)
);
GO

-- Create ArticleTag Table
CREATE TABLE ArticleTag (
    ArticleID       INT             NOT NULL
    ,TagID          INT             NOT NULL

    ,CONSTRAINT PK_ArticleTag        PRIMARY KEY CLUSTERED      (ArticleID, TagID)
    ,CONSTRAINT FK_ArticleTag_Art    FOREIGN KEY                (ArticleID) REFERENCES Article(ArticleID)
    ,CONSTRAINT FK_ArticleTag_Tag    FOREIGN KEY                (TagID)     REFERENCES Tag(TagID)
);
GO

-- Create Notification Table
CREATE TABLE [Notification] (
    NotificationID  INT             NOT NULL    IDENTITY(1,1)
    ,Type           VARCHAR(50)     NOT NULL
    ,CreatedAt      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,ArticleID      INT             NOT NULL
    ,UserID         INT             NOT NULL

    ,CONSTRAINT PK_Notification          PRIMARY KEY CLUSTERED  (NotificationID)
    ,CONSTRAINT FK_Notification_Article  FOREIGN KEY            (ArticleID) REFERENCES Article(ArticleID)
    ,CONSTRAINT FK_Notification_User     FOREIGN KEY            (UserID)    REFERENCES [User](UserID)
);
GO

-- Create ViewLog Table
-- Captures article read events for all users including those with no clearance.
-- UserID is nullable to support anonymous / unauthenticated readers.
CREATE TABLE ViewLog (
    ViewID          INT             NOT NULL    IDENTITY(1,1)
    ,TimeStamp      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,ArticleID      INT             NOT NULL
    ,UserID         INT             NULL        -- NULL = anonymous reader
    ,Duration       INT             NULL        -- seconds spent reading

    ,CONSTRAINT PK_ViewLog              PRIMARY KEY CLUSTERED   (ViewID)
    ,CONSTRAINT FK_ViewLog_Article      FOREIGN KEY             (ArticleID) REFERENCES Article(ArticleID)
    ,CONSTRAINT FK_ViewLog_User         FOREIGN KEY             (UserID)    REFERENCES [User](UserID)
);
GO

-- Create AuditLog TAble
CREATE TABLE AuditLog (
    LogID           INT             NOT NULL    IDENTITY(1,1)
    ,Action         VARCHAR(50)     NOT NULL
    ,TimeStamp      DATETIME2       NOT NULL    DEFAULT GETDATE()
    ,UserID         INT             NOT NULL
    ,ArticleID      INT             NOT NULL

    ,CONSTRAINT PK_AuditLog         PRIMARY KEY CLUSTERED       (LogID)
    ,CONSTRAINT FK_AuditLog_User    FOREIGN KEY                 (UserID)    REFERENCES [User](UserID)
    ,CONSTRAINT FK_AuditLog_Article FOREIGN KEY                 (ArticleID) REFERENCES Article(ArticleID)
);
GO


-- ------------------------------------------------------------
--  3. INDEXES
-- ------------------------------------------------------------

CREATE NONCLUSTERED INDEX idx_User_DepartmentID  ON [User]       (DepartmentID);
CREATE NONCLUSTERED INDEX idx_User_RoleID        ON [User]       (RoleID);
                          
CREATE NONCLUSTERED INDEX idx_Article_UserID     ON Article      (UserID);
CREATE NONCLUSTERED INDEX idx_Article_CategoryID ON Article      (CategoryID);
CREATE NONCLUSTERED INDEX idx_Article_DeptID     ON Article      (DepartmentID);
CREATE NONCLUSTERED INDEX idx_Article_Status     ON Article      (Status);
CREATE NONCLUSTERED INDEX idx_Article_CreatedAt  ON Article      (CreatedAt);
                          
CREATE NONCLUSTERED INDEX idx_AuditLog_UserID    ON AuditLog     (UserID);
CREATE NONCLUSTERED INDEX idx_AuditLog_ArticleID ON AuditLog     (ArticleID);
CREATE NONCLUSTERED INDEX idx_AuditLog_TimeStamp ON AuditLog     (TimeStamp);
CREATE NONCLUSTERED INDEX idx_AuditLog_Action    ON AuditLog     (Action);
                          
CREATE NONCLUSTERED INDEX idx_Notif_ArticleID    ON Notification (ArticleID);
CREATE NONCLUSTERED INDEX idx_Notif_UserID       ON Notification (UserID);
                          
CREATE NONCLUSTERED INDEX idx_ViewLog_ArticleID  ON ViewLog      (ArticleID);
CREATE NONCLUSTERED INDEX idx_ViewLog_UserID     ON ViewLog      (UserID);
CREATE NONCLUSTERED INDEX idx_ViewLog_TimeStamp  ON ViewLog      (TimeStamp);
GO


-- ------------------------------------------------------------
--  4. SEED DATA
-- ------------------------------------------------------------

INSERT INTO Department (Name) VALUES
    ('Press'),
    ('Technology'),
    ('HR'),
    ('Finance'),
    ('Marketing');
GO

-- OF ranks of different ranks in swedish military and the OR rank conversion
INSERT INTO SecurityRole (RoleName, SecurityLevel) VALUES
    ('Civilian',            0),
    ('Menig',               1),   -- OR 1-2
    ('Korpral',             2),   -- OR 4
    ('Sergeant',            3),   -- OR 6
    ('Fanjunkare',          4),   -- OR 7
    ('Förvaltare',          5),   -- OR 8
    ('Fänrik',              6),   -- OF 1
    ('Löjtnant',            7),   -- OF 1
    ('Kapten',              8),   -- OF 2
    ('Major',               9),   -- OF 3
    ('Överstelöjtnant',     10),  -- OF 4
    ('Överste',             11),  -- OF 5
    ('Brigadgeneral',       12),  -- OF 6
    ('Generalmajor',        13),  -- OF 7
    ('Generallöjtnant',     14),  -- OF 8
    ('General',             15);  -- OF 9
GO

INSERT INTO [User] (FirstName, LastName, Email, DepartmentID, RoleID) VALUES
    ('Anna',    'Svensson',     'anna.svensson@company.se',     1, 4),   -- Press    / Editor
    ('Erik',    'Lindqvist',    'erik.lindqvist@company.se',    2, 2),   -- Tech     / Author
    ('Maria',   'Johansson',    'maria.johansson@company.se',   3, 2),   -- HR       / Author
    ('Lars',    'Bergstrom',    'lars.bergstrom@company.se',    4, 2),   -- Finance  / Author
    ('Sofia',   'Eriksson',     'sofia.eriksson@company.se',    5, 2),   -- Marketing/ Author
    ('Johan',   'Nilsson',      'johan.nilsson@company.se',     1, 3),   -- Press    / Reviewer
    ('Karin',   'Pettersson',   'karin.pettersson@company.se',  2, 3),   -- Tech     / Reviewer
    ('Mikael',  'Holm',         'mikael.holm@company.se',       1, 5),   -- Press    / Admin
    ('Lena',    'Gustafsson',   'lena.gustafsson@company.se',   3, 1),   -- HR       / Viewer
    ('Anders',  'Magnusson',    'anders.magnusson@company.se',  5, 2);   -- Marketing/ Author
GO

INSERT INTO Category (Name) VALUES
    ('Internal News'),
    ('Policy Update'),
    ('Tech Report'),
    ('Press Release'),
    ('Financial Update');
GO

INSERT INTO Tag (Name) VALUES
    ('Urgent'),
    ('Confidential'),
    ('Public'),
    ('Draft'),
    ('Archived');
GO

-- Articles
-- Status: 0=Draft  1=Submitted  2=Approved  3=Rejected  4=ChangesRequested
INSERT INTO Article (Title, Content, Status, SecurityLevel, CreatedAt, PublishedAt, CategoryID, TagID, DepartmentID, UserID) VALUES
    ('Q1 Tech Report 2026',
     'This report covers all technology initiatives in Q1 2026 including infrastructure upgrades and software deployments. Budget utilization was 94%. Key achievements include migration to cloud storage and rollout of a new CI/CD pipeline.',
     2, 2, '2026-01-05 08:00:00', '2026-01-12 14:30:00', 3, 3, 2, 2),

    ('Updated Remote Work Policy',
     'Following feedback from the annual employee survey, HR revised the remote work policy. Employees may now work remotely up to four days per week subject to manager approval. Effective 2026-02-01.',
     1, 2, '2026-01-20 09:15:00', NULL, 2, NULL, 3, 3),

    ('Marketing Campaign Results - Winter 2025',
     'Overview of the winter 2025 campaign across digital and print channels. Conversion rate increased 12% versus the prior year. Total reach was 1.4 million unique impressions.',
     3, 1, '2026-01-18 10:00:00', NULL, 4, 1, 5, 5),

    ('Company Reaches 500 Employees',
     'We are proud to announce that our organisation officially reached 500 full-time employees in January 2026. This milestone reflects our continued growth and commitment to building a world-class team.',
     2, 1, '2026-01-25 11:00:00', '2026-01-28 09:00:00', 4, 3, 1, 1),

    ('Finance Quarterly Outlook Q2 2026',
     'Preliminary analysis of Q2 2026 financial outlook based on current market conditions and internal forecasts. Revenue projections indicate 8% YoY growth. Pending CFO approval.',
     0, 3, '2026-02-01 13:00:00', NULL, 5, 2, 4, 4),

    ('New Onboarding Process for 2026',
     'HR proposes a revised onboarding process reducing time-to-productivity from 4 weeks to 2.5 weeks. Changes include a structured buddy programme and automated access provisioning.',
     4, 2, '2026-02-10 08:30:00', NULL, 2, NULL, 3, 3),

    ('Security Level Update - All Departments',
     'Following the annual security review, all department security levels have been reassessed. Employees are reminded to complete the mandatory security training module by end of February.',
     2, 4, '2026-02-14 09:00:00', '2026-02-16 10:00:00', 1, 2, 1, 8),

    ('Tech Stack Modernisation Proposal',
     'The technology department proposes migrating the core application stack from .NET Framework 4.8 to .NET 8. Estimated timeline is 6 months with a projected 30% reduction in hosting costs.',
     1, 3, '2026-02-20 14:00:00', NULL, 3, NULL, 2, 7),

    ('Marketing Strategy H1 2026',
     'This document outlines the marketing strategy for the first half of 2026 focusing on digital-first campaigns, influencer partnerships and SEO improvements. Budget confirmed at 2.1M SEK.',
     2, 2, '2026-03-01 10:00:00', '2026-03-05 08:00:00', 4, 3, 5, 10),

    ('Internal IT Security Guidelines v3',
     'Version 3 of the internal IT security guidelines covering password policies, VPN usage, device management and incident reporting procedures. Review by the IT security team is pending.',
     0, 4, '2026-03-15 11:00:00', NULL, 1, 2, 2, 2);
GO

-- ArticleTag  (several articles carry multiple tags)
INSERT INTO ArticleTag (ArticleID, TagID) VALUES
    (1,  3),   -- Q1 Tech Report        -> Public
    (1,  1),   -- Q1 Tech Report        -> Urgent
    (3,  1),   -- Marketing Results     -> Urgent
    (4,  3),   -- 500 Employees         -> Public
    (5,  2),   -- Finance Outlook       -> Confidential
    (7,  2),   -- Security Update       -> Confidential
    (7,  1),   -- Security Update       -> Urgent
    (8,  4),   -- Tech Stack Proposal   -> Draft
    (9,  3),   -- Marketing Strategy    -> Public
    (10, 2),   -- IT Guidelines         -> Confidential
    (10, 4);   -- IT Guidelines         -> Draft
GO

-- AuditLog  (realistic workflow events for every article)
INSERT INTO AuditLog (Action, TimeStamp, UserID, ArticleID) VALUES
    -- Article 1: full lifecycle
    ('Draft',           '2026-01-05 08:00:00', 2,  1),
    ('Submit',          '2026-01-06 09:30:00', 2,  1),
    ('Review',          '2026-01-07 10:00:00', 6,  1),
    ('Approve',         '2026-01-10 11:00:00', 1,  1),
    ('Publish',         '2026-01-12 14:30:00', 8,  1),

    -- Article 2: submitted, awaiting review
    ('Draft',           '2026-01-20 09:15:00', 3,  2),
    ('Submit',          '2026-01-22 10:00:00', 3,  2),
    ('Review',          '2026-01-24 14:00:00', 6,  2),

    -- Article 3: rejected
    ('Draft',           '2026-01-18 10:00:00', 5,  3),
    ('Submit',          '2026-01-19 11:30:00', 5,  3),
    ('Review',          '2026-01-20 13:00:00', 6,  3),
    ('Reject',          '2026-01-21 09:00:00', 1,  3),

    -- Article 4: approved and published
    ('Draft',           '2026-01-25 11:00:00', 1,  4),
    ('Submit',          '2026-01-26 08:00:00', 1,  4),
    ('Review',          '2026-01-26 12:00:00', 6,  4),
    ('Approve',         '2026-01-27 10:00:00', 1,  4),
    ('Publish',         '2026-01-28 09:00:00', 8,  4),

    -- Article 5: still in draft
    ('Draft',           '2026-02-01 13:00:00', 4,  5),

    -- Article 6: changes requested
    ('Draft',           '2026-02-10 08:30:00', 3,  6),
    ('Submit',          '2026-02-11 09:00:00', 3,  6),
    ('Review',          '2026-02-12 10:30:00', 6,  6),
    ('RequestChange',   '2026-02-13 11:00:00', 1,  6),

    -- Article 7: high-security, approved and published
    ('Draft',           '2026-02-14 09:00:00', 8,  7),
    ('Submit',          '2026-02-14 10:00:00', 8,  7),
    ('Review',          '2026-02-15 09:00:00', 6,  7),
    ('Approve',         '2026-02-15 14:00:00', 8,  7),
    ('Publish',         '2026-02-16 10:00:00', 8,  7),

    -- Article 8: submitted
    ('Draft',           '2026-02-20 14:00:00', 7,  8),
    ('Submit',          '2026-02-22 09:00:00', 7,  8),

    -- Article 9: approved and published
    ('Draft',           '2026-03-01 10:00:00', 10, 9),
    ('Submit',          '2026-03-02 08:30:00', 10, 9),
    ('Review',          '2026-03-03 10:00:00', 6,  9),
    ('Approve',         '2026-03-04 11:00:00', 1,  9),
    ('Publish',         '2026-03-05 08:00:00', 8,  9),

    -- Article 10: still in draft
    ('Draft',           '2026-03-15 11:00:00', 2,  10);
GO

-- Notifications  (triggered by key workflow status changes)
INSERT INTO Notification (Type, CreatedAt, ArticleID, UserID) VALUES
    ('ArticleSubmitted',    '2026-01-06 09:30:00', 1,  6),
    ('ArticleApproved',     '2026-01-10 11:00:00', 1,  2),
    ('ArticlePublished',    '2026-01-12 14:30:00', 1,  2),
    ('ArticleSubmitted',    '2026-01-22 10:00:00', 2,  6),
    ('ArticleSubmitted',    '2026-01-19 11:30:00', 3,  6),
    ('ArticleRejected',     '2026-01-21 09:00:00', 3,  5),
    ('ArticleSubmitted',    '2026-01-26 08:00:00', 4,  6),
    ('ArticleApproved',     '2026-01-27 10:00:00', 4,  1),
    ('ArticlePublished',    '2026-01-28 09:00:00', 4,  1),
    ('ChangesRequested',    '2026-02-13 11:00:00', 6,  3),
    ('ArticleSubmitted',    '2026-02-14 10:00:00', 7,  6),
    ('ArticleApproved',     '2026-02-15 14:00:00', 7,  8),
    ('ArticlePublished',    '2026-02-16 10:00:00', 7,  8),
    ('ArticleSubmitted',    '2026-02-22 09:00:00', 8,  6),
    ('ArticleSubmitted',    '2026-03-02 08:30:00', 9,  6),
    ('ArticleApproved',     '2026-03-04 11:00:00', 9,  10),
    ('ArticlePublished',    '2026-03-05 08:00:00', 9,  10);
GO


-- ------------------------------------------------------------
--  5. SEED DATA — ViewLog
--  Mix of authenticated users (including Viewer role) and
--  anonymous reads (UserID NULL) to represent readers with
--  no security clearance.
-- ------------------------------------------------------------

-- Published articles: 1, 4, 7, 9
INSERT INTO ViewLog (TimeStamp, ArticleID, UserID, Duration) VALUES
    -- Article 1: Q1 Tech Report  (published 2026-01-12)
    ('2026-01-12 15:00:00', 1,  9,    142),  -- Lena (Viewer / HR)
    ('2026-01-13 08:30:00', 1,  NULL, 95),   -- anonymous
    ('2026-01-13 09:10:00', 1,  NULL, 210),  -- anonymous
    ('2026-01-14 11:00:00', 1,  3,    188),  -- Maria (Author / HR)
    ('2026-01-15 14:00:00', 1,  NULL, 60),   -- anonymous

    -- Article 4: 500 Employees  (published 2026-01-28)
    ('2026-01-28 10:00:00', 4,  9,    75),   -- Lena (Viewer)
    ('2026-01-28 10:30:00', 4,  NULL, 120),  -- anonymous
    ('2026-01-28 11:00:00', 4,  NULL, 88),   -- anonymous
    ('2026-01-29 08:00:00', 4,  5,    95),   -- Sofia (Author)
    ('2026-01-29 09:00:00', 4,  NULL, 55),   -- anonymous

    -- Article 7: Security Level Update  (published 2026-02-16)
    ('2026-02-16 11:00:00', 7,  9,    320),  -- Lena (Viewer — high-sec article)
    ('2026-02-16 12:00:00', 7,  2,    275),  -- Erik (Author / Tech)
    ('2026-02-17 08:30:00', 7,  NULL, 180),  -- anonymous
    ('2026-02-17 09:00:00', 7,  NULL, 210),  -- anonymous
    ('2026-02-18 10:00:00', 7,  4,    155),  -- Lars (Author / Finance)

    -- Article 9: Marketing Strategy  (published 2026-03-05)
    ('2026-03-05 09:00:00', 9,  9,    98),   -- Lena (Viewer)
    ('2026-03-05 09:30:00', 9,  NULL, 140),  -- anonymous
    ('2026-03-06 10:00:00', 9,  NULL, 77),   -- anonymous
    ('2026-03-06 11:00:00', 9,  3,    165),  -- Maria (Author)
    ('2026-03-07 08:00:00', 9,  NULL, 50);   -- anonymous
GO


-- ------------------------------------------------------------
--  6. QUICK VERIFICATION
-- ------------------------------------------------------------
SELECT 'Department'  AS [Table],  COUNT(*) AS [Rows] FROM Department
UNION ALL SELECT 'SecurityRole',  COUNT(*) FROM SecurityRole
UNION ALL SELECT 'User',          COUNT(*) FROM [User]
UNION ALL SELECT 'Category',      COUNT(*) FROM Category
UNION ALL SELECT 'Tag',           COUNT(*) FROM Tag
UNION ALL SELECT 'Article',       COUNT(*) FROM Article
UNION ALL SELECT 'ArticleTag',    COUNT(*) FROM ArticleTag
UNION ALL SELECT 'AuditLog',      COUNT(*) FROM AuditLog
UNION ALL SELECT 'ViewLog',       COUNT(*) FROM ViewLog
UNION ALL SELECT 'Notification',  COUNT(*) FROM Notification;
GO
