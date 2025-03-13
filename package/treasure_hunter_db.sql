IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'treasure_hunter_db')
BEGIN
    CREATE DATABASE treasure_hunter_db;
END
GO

USE treasure_hunter_db;
GO

-- Włączenie Full-Text Search (jeśli nie jest włączone)
IF SERVERPROPERTY('IsFullTextInstalled') = 1 AND 
   (SELECT fulltextserviceproperty('IsFullTextInstalled')) = 0
BEGIN
    EXEC sp_fulltext_database 'enable';
END
GO

-- Tabela Roles
/* 
Zastosowanie: Tabela definiuje role użytkowników (np. "Searcher", "Administrator"), co pozwala na zarządzanie uprawnieniami w systemie.
Dlaczego: Umożliwia rozróżnienie funkcji użytkowników i przypisanie odpowiednich zadań, np. administracyjnych lub operacyjnych.
Korzyści: Zwiększa elastyczność i bezpieczeństwo systemu poprzez kontrolę dostępu.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles
    (
        RoleID   INT IDENTITY,
        RoleName NVARCHAR(20) NOT NULL UNIQUE,
        CONSTRAINT PK_Roles PRIMARY KEY (RoleID)
    );
    
    INSERT INTO Roles (RoleName) VALUES 
        ('Searcher'), 
        ('Administrator');
END
GO

-- Tabela Users
/* 
Zastosowanie: Przechowuje dane użytkowników, w tym zahashowane hasła i przypisane role.
Dlaczego: Umożliwia identyfikację i autoryzację użytkowników w systemie.
Korzyści: Zahashowane hasła zwiększają bezpieczeństwo, a powiązanie z rolami ułatwia zarządzanie uprawnieniami.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users
    (
        UserID       INT IDENTITY,
        Username     NVARCHAR(50)  NOT NULL UNIQUE,
        PasswordHash VARBINARY(256) NOT NULL,
        FullName     NVARCHAR(100),
        Email        NVARCHAR(50) CHECK (Email LIKE '%@%.%'),
        RoleID       INT NOT NULL CONSTRAINT FK_Users_Roles REFERENCES Roles(RoleID),
        CONSTRAINT PK_Users PRIMARY KEY (UserID)
    );

    INSERT INTO Users (Username, PasswordHash, FullName, Email, RoleID) VALUES 
        ('john_doe', HASHBYTES('SHA2_256', 'password123'), 'John Doe', 'john.doe@example.com', 1),
        ('admin_jane', HASHBYTES('SHA2_256', 'adminpass'), 'Jane Smith', 'jane.smith@example.com', 2),
        ('mary_search', HASHBYTES('SHA2_256', 'marypass'), 'Mary Johnson', 'mary.j@example.com', 1);
END
GO

-- Tabela Clients
/* 
Zastosowanie: Przechowuje dane klientów zlecających poszukiwania, w tym lokalizację geograficzną i elastyczne pole JSON.
Dlaczego: Umożliwia zarządzanie informacjami o klientach i ich specyficznymi wymaganiami.
Korzyści: Pole GEOGRAPHY wspiera analizę lokalizacji, a JSON (`AdditionalInfo`) pozwala na elastyczne rozszerzanie danych bez zmiany schematu.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Clients')
BEGIN
    CREATE TABLE Clients
    (
        ClientID        INT IDENTITY,
        FirstName       NVARCHAR(50)  NOT NULL,
        LastName        NVARCHAR(50)  NOT NULL,
        Address         NVARCHAR(100) NOT NULL,
        City            NVARCHAR(50)  NOT NULL,
        PostalCode      VARCHAR(10),
        Country         NVARCHAR(50),
        Phone           VARCHAR(20),
        Email           NVARCHAR(50) CHECK (Email LIKE '%@%.%'),
        AdditionalInfo  NVARCHAR(MAX) CONSTRAINT DF_Clients_AdditionalInfo DEFAULT ('{}') CHECK (ISJSON(AdditionalInfo) = 1),
        Location        GEOGRAPHY,
        ManagedByUserID INT CONSTRAINT FK_Clients_User_ManagedBy REFERENCES Users(UserID),
        CONSTRAINT PK_Clients PRIMARY KEY (ClientID)
    );

    INSERT INTO Clients (FirstName, LastName, Address, City, PostalCode, Country, Phone, Email, AdditionalInfo, Location, ManagedByUserID) VALUES 
        ('Anna', 'Kowalska', 'ul. Zielona 12', 'Warszawa', '00-123', 'Polska', '123456789', 'anna.k@example.com', '{"preferred_contact": "email"}', GEOGRAPHY::Point(52.2297, 21.0122, 4326), 1),
        ('Peter', 'Brown', '10 High Street', 'London', 'SW1A 1AA', 'UK', '447890123456', 'peter.b@example.com', '{"notes": "VIP client"}', GEOGRAPHY::Point(51.5074, -0.1278, 4326), 2),
        ('Katarzyna', 'Nowak', 'ul. Lipowa 5', 'Kraków', '30-001', 'Polska', '987654321', 'katarzyna.n@example.com', '{}', GEOGRAPHY::Point(50.0647, 19.9450, 4326), 3);

    CREATE INDEX IX_Clients_LastName ON Clients (LastName);
    CREATE INDEX IX_Clients_Name ON Clients (LastName, FirstName);
    CREATE INDEX IX_Clients_ManagedBy ON Clients (ManagedByUserID);
END
GO

-- Indeks pełnotekstowy dla Clients
/* 
Zastosowanie: Umożliwia szybkie wyszukiwanie w polu `AdditionalInfo` klientów.
Dlaczego: Przyspiesza przeszukiwanie niestandardowych danych zapisanych w JSON.
Korzyści: Ułatwia analizę szczegółów klientów bez obciążania aplikacji złożonymi zapytaniami.
*/
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'ClientsFullTextCatalog')
BEGIN
    CREATE FULLTEXT CATALOG ClientsFullTextCatalog;
END
GO

IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('Clients'))
BEGIN
    CREATE FULLTEXT INDEX ON Clients (AdditionalInfo) 
    KEY INDEX PK_Clients 
    ON ClientsFullTextCatalog;
END
GO

-- Tabela Contacts
/* 
Zastosowanie: Zarządza osobami kontaktowymi powiązanymi z klientami lub zamówieniami, z opcją śledzenia poleceń.
Dlaczego: Umożliwia budowanie sieci kontaktów i przypisywanie odpowiedzialności.
Korzyści: Relacja `ReferredByContactID` wspiera analizę źródeł biznesowych, a indeksy przyspieszają wyszukiwanie.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Contacts')
BEGIN
    CREATE TABLE Contacts
    (
        ContactID           INT IDENTITY,
        FirstName           NVARCHAR(50) NOT NULL,
        LastName            NVARCHAR(50) NOT NULL,
        Company             NVARCHAR(50),
        Position            NVARCHAR(50),
        Phone               VARCHAR(20),
        Email               NVARCHAR(50) CHECK (Email LIKE '%@%.%'),
        Address             NVARCHAR(100),
        City                NVARCHAR(50),
        PostalCode          VARCHAR(10),
        Country             NVARCHAR(50),
        ReferredByContactID INT CONSTRAINT FK_Contacts_Referred REFERENCES Contacts(ContactID),
        ClientID            INT CONSTRAINT FK_Contacts_Client REFERENCES Clients(ClientID),
        ManagedByUserID     INT CONSTRAINT FK_Contacts_User_ManagedBy REFERENCES Users(UserID),
        CONSTRAINT PK_Contacts PRIMARY KEY (ContactID)
    );

    INSERT INTO Contacts (FirstName, LastName, Company, Position, Phone, Email, Address, City, PostalCode, Country, ReferredByContactID, ClientID, ManagedByUserID) VALUES 
        ('Jan', 'Wiśniewski', 'Treasure Ltd', 'Manager', '111222333', 'jan.w@example.com', 'ul. Słoneczna 8', 'Warszawa', '00-456', 'Polska', NULL, 1, 1),
        ('Emma', 'Taylor', 'Gold Seekers', 'Director', '447123456789', 'emma.t@example.com', '15 Baker St', 'London', 'NW1 6XB', 'UK', NULL, 2, 2),
        ('Tomasz', 'Kowal', NULL, 'Assistant', '555666777', 'tomasz.k@example.com', 'ul. Wiosenna 3', 'Kraków', '30-002', 'Polska', 1, 3, 3);

    CREATE INDEX IX_Contacts_ClientID ON Contacts (ClientID);
    CREATE INDEX IX_Contacts_ManagedByUserID ON Contacts (ManagedByUserID);
END
GO

-- Tabela OrderStatuses
/* 
Zastosowanie: Definiuje standardowe statusy zamówień (np. "New", "In Progress").
Dlaczego: Zapewnia spójność i czytelność stanów procesów w systemie.
Korzyści: Ułatwia śledzenie postępu i raportowanie bez ryzyka błędów w nazewnictwie.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OrderStatuses')
BEGIN
    CREATE TABLE OrderStatuses
    (
        StatusID   INT IDENTITY,
        StatusName NVARCHAR(50) NOT NULL UNIQUE,
        CONSTRAINT PK_OrderStatuses PRIMARY KEY (StatusID)
    );
    
    INSERT INTO OrderStatuses (StatusName) VALUES 
        ('New'), 
        ('In Progress'), 
        ('Completed');
END
GO

-- Tabela Orders
/* 
Zastosowanie: Łączy klientów z zamówieniami, przechowując daty, opisy i dodatkowe dane w JSON.
Dlaczego: Umożliwia zarządzanie zleceniami poszukiwań i ich szczegółami.
Korzyści: Indeksy optymalizują raportowanie, a pole `AdditionalInfo` pozwala na elastyczne przechowywanie specyficznych informacji.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Orders')
BEGIN
    CREATE TABLE Orders
    (
        OrderID          INT IDENTITY,
        ClientID         INT NOT NULL CONSTRAINT FK_Orders_Client REFERENCES Clients(ClientID),
        OrderDate        DATE NOT NULL,
        DeadlineDate     DATE,
        Description      NVARCHAR(255) NOT NULL,
        StatusID         INT NOT NULL CONSTRAINT FK_Orders_Status REFERENCES OrderStatuses(StatusID),
        AdditionalInfo   NVARCHAR(MAX) CONSTRAINT DF_Orders_AdditionalInfo DEFAULT ('{}') CHECK (ISJSON(AdditionalInfo) = 1),
        AssignedToUserID INT CONSTRAINT FK_Orders_User_AssignedTo REFERENCES Users(UserID),
        CONSTRAINT PK_Orders PRIMARY KEY (OrderID)
    );

    INSERT INTO Orders (ClientID, OrderDate, DeadlineDate, Description, StatusID, AdditionalInfo, AssignedToUserID) VALUES 
        (1, '2025-03-01', '2025-04-01', 'Search for medieval treasure in Mazovia', 1, '{"priority": "high"}', 1),
        (2, '2025-03-05', '2025-05-01', 'Locate shipwreck near Cornwall', 2, '{"depth": "50m"}', 2),
        (3, '2025-03-10', NULL, 'Explore old mine in Lesser Poland', 3, '{}', 3);

    CREATE INDEX IX_Orders_Date_Status ON Orders (OrderDate, StatusID);
    CREATE INDEX IX_Orders_ClientID ON Orders (ClientID);
    CREATE INDEX IX_Orders_AssignedToUserID ON Orders (AssignedToUserID);
END
GO

-- Indeks pełnotekstowy dla Orders
/* 
Zastosowanie: Umożliwia szybkie wyszukiwanie w polu `AdditionalInfo` zamówień.
Dlaczego: Przyspiesza analizę szczegółów zleceń zapisanych w JSON.
Korzyści: Ułatwia użytkownikom szybkie odnalezienie kluczowych informacji bez złożonych zapytań.
*/
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'OrdersFullTextCatalog')
BEGIN
    CREATE FULLTEXT CATALOG OrdersFullTextCatalog;
END
GO

IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('Orders'))
BEGIN
    CREATE FULLTEXT INDEX ON Orders (AdditionalInfo) 
    KEY INDEX PK_Orders 
    ON OrdersFullTextCatalog;
END
GO

-- Tabela OrderAudit
/* 
Zastosowanie: Przechowuje historię zmian statusu zamówień.
Dlaczego: Umożliwia audyt i śledzenie zmian w procesach poszukiwania skarbów.
Korzyści: Zapewnia transparentność i rozliczalność, np. w sporach z klientami lub analizie pracy zespołu.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OrderAudit')
BEGIN
    CREATE TABLE OrderAudit
    (
        AuditID         INT IDENTITY PRIMARY KEY,
        OrderID         INT NOT NULL,
        OldStatusID     INT,
        NewStatusID     INT,
        ChangeDate      DATETIME DEFAULT GETDATE(),
        ChangedByUserID INT CONSTRAINT FK_OrderAudit_Users REFERENCES Users(UserID)
    );

    -- Przykładowe dane (zakładamy, że status zamówienia 2 zmienił się z 1 na 2)
    INSERT INTO OrderAudit (OrderID, OldStatusID, NewStatusID, ChangedByUserID) VALUES 
        (2, 1, 2, 2);
END
GO

-- Trigger TR_Orders_StatusUpdate
/* 
Zastosowanie: Automatycznie zapisuje zmiany statusu zamówień w tabeli `OrderAudit`.
Dlaczego: Eliminuje potrzebę ręcznego logowania zmian przez aplikację.
Korzyści: Zwiększa niezawodność audytu i zmniejsza obciążenie programistów aplikacji.
*/
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Orders_StatusUpdate')
BEGIN
    EXEC('CREATE TRIGGER TR_Orders_StatusUpdate
    ON Orders
    AFTER UPDATE
    AS
    BEGIN
        IF UPDATE(StatusID)
        BEGIN
            INSERT INTO OrderAudit (OrderID, OldStatusID, NewStatusID, ChangedByUserID)
            SELECT 
                i.OrderID,
                d.StatusID AS OldStatusID,
                i.StatusID AS NewStatusID,
                i.AssignedToUserID
            FROM inserted i
            JOIN deleted d ON i.OrderID = d.OrderID
            WHERE i.StatusID != d.StatusID;
        END
    END');
END
GO

-- Tabela CostTypes
/* 
Zastosowanie: Definiuje kategorie kosztów (np. transport, sprzęt).
Dlaczego: Umożliwia klasyfikację wydatków związanych z poszukiwaniami.
Korzyści: Ułatwia analizę finansową i raportowanie kosztów według typów.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CostTypes')
BEGIN
    CREATE TABLE CostTypes
    (
        CostTypeID INT IDENTITY,
        Name       NVARCHAR(50) NOT NULL UNIQUE,
        CONSTRAINT PK_CostTypes PRIMARY KEY (CostTypeID)
    );

    INSERT INTO CostTypes (Name) VALUES 
        ('Transport'), 
        ('Equipment'), 
        ('Personnel');
END
GO

-- Tabela Costs
/* 
Zastosowanie: Przechowuje koszty powiązane z zamówieniami, klientami lub kontaktami.
Dlaczego: Umożliwia szczegółowe rozliczanie wydatków w projektach.
Korzyści: Indeksy przyspieszają zapytania analityczne, a elastyczne powiązania zwiększają użyteczność danych.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Costs')
BEGIN
    CREATE TABLE Costs
    (
        CostID           INT IDENTITY,
        CostDate         DATE NOT NULL,
        Amount           DECIMAL(12, 2) NOT NULL,
        CostTypeID       INT NOT NULL CONSTRAINT FK_Costs_CostType REFERENCES CostTypes(CostTypeID),
        Description      NVARCHAR(255),
        OrderID          INT CONSTRAINT FK_Costs_Order REFERENCES Orders(OrderID),
        ClientID         INT CONSTRAINT FK_Costs_Client REFERENCES Clients(ClientID),
        ContactID        INT CONSTRAINT FK_Costs_Contact REFERENCES Contacts(ContactID),
        ReportedByUserID INT NOT NULL CONSTRAINT FK_Costs_User_ReportedBy REFERENCES Users(UserID),
        CONSTRAINT PK_Costs PRIMARY KEY (CostID)
    );

    INSERT INTO Costs (CostDate, Amount, CostTypeID, Description, OrderID, ClientID, ContactID, ReportedByUserID) VALUES 
        ('2025-03-02', 1500.00, 1, 'Fuel for trip to Mazovia', 1, 1, NULL, 1),
        ('2025-03-06', 2000.00, 2, 'Diving gear rental', 2, 2, 2, 2),
        ('2025-03-11', 800.00, 3, 'Assistant wages', 3, 3, 3, 3);

    CREATE INDEX IX_Costs_OrderID ON Costs (OrderID);
    CREATE INDEX IX_Costs_ClientID ON Costs (ClientID);
    CREATE INDEX IX_Costs_ContactID ON Costs (ContactID);
    CREATE INDEX IX_Costs_ReportedByUserID ON Costs (ReportedByUserID);
END
GO

-- Tabela Notes
/* 
Zastosowanie: Przechowuje notatki powiązane z klientami, zamówieniami lub kontaktami.
Dlaczego: Umożliwia dokumentowanie szczegółów i obserwacji w procesie poszukiwań.
Korzyści: Ograniczenie `CHK_Notes_OneEntity` zapewnia spójność, a indeksy filtrowane zwiększają wydajność zapytań.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Notes')
BEGIN
    CREATE TABLE Notes
    (
        NoteID          INT IDENTITY,
        NoteText        NVARCHAR(MAX) NOT NULL,
        CreatedDate     DATETIME DEFAULT GETDATE(),
        CreatedByUserID INT NOT NULL CONSTRAINT FK_Notes_User_CreatedBy REFERENCES Users(UserID),
        ClientID        INT CONSTRAINT FK_Notes_Client REFERENCES Clients(ClientID),
        OrderID         INT CONSTRAINT FK_Notes_Order REFERENCES Orders(OrderID),
        ContactID       INT CONSTRAINT FK_Notes_Contact REFERENCES Contacts(ContactID),
        CONSTRAINT PK_Notes PRIMARY KEY (NoteID),
        CONSTRAINT CHK_Notes_OneEntity CHECK (
            (ClientID IS NOT NULL AND OrderID IS NULL AND ContactID IS NULL) OR
            (ClientID IS NULL AND OrderID IS NOT NULL AND ContactID IS NULL) OR
            (ClientID IS NULL AND OrderID IS NULL AND ContactID IS NOT NULL)
        )
    );

    INSERT INTO Notes (NoteText, CreatedByUserID, ClientID, OrderID, ContactID) VALUES 
        ('Client prefers updates via email', 1, 1, NULL, NULL),
        ('Shipwreck site confirmed at 50m depth', 2, NULL, 2, NULL),
        ('Contact confirmed availability', 3, NULL, NULL, 3);

    CREATE INDEX IX_Notes_ClientID ON Notes (ClientID) WHERE ClientID IS NOT NULL;
    CREATE INDEX IX_Notes_OrderID ON Notes (OrderID) WHERE OrderID IS NOT NULL;
    CREATE INDEX IX_Notes_ContactID ON Notes (ContactID) WHERE ContactID IS NOT NULL;
END
GO

-- Indeks pełnotekstowy dla Notes
/* 
Zastosowanie: Umożliwia szybkie wyszukiwanie tekstowe w treści notatek.
Dlaczego: Przyspiesza odnalezienie kluczowych informacji w dużych ilościach tekstu.
Korzyści: Ułatwia użytkownikom analizę i wyszukiwanie bez obciążania aplikacji.
*/
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'NotesFullTextCatalog')
BEGIN
    CREATE FULLTEXT CATALOG NotesFullTextCatalog;
END
GO

IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('Notes'))
BEGIN
    CREATE FULLTEXT INDEX ON Notes (NoteText) 
    KEY INDEX PK_Notes 
    ON NotesFullTextCatalog;
END
GO

-- Tabela OrderContacts
/* 
Zastosowanie: Łączy kontakty z zamówieniami, umożliwiając przypisanie wielu osób do zlecenia.
Dlaczego: Wspiera zarządzanie złożonymi projektami wymagającymi współpracy.
Korzyści: Klucz złożony zapewnia unikalność powiązań, co ułatwia organizację pracy.
*/
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OrderContacts')
BEGIN
    CREATE TABLE OrderContacts
    (
        OrderID          INT NOT NULL CONSTRAINT FK_OrderContacts_Order REFERENCES Orders(OrderID),
        ContactID        INT NOT NULL CONSTRAINT FK_OrderContacts_Contact REFERENCES Contacts(ContactID),
        AssignedByUserID INT NOT NULL CONSTRAINT FK_OrderContacts_User_AssignedBy REFERENCES Users(UserID),
        CONSTRAINT PK_OrderContacts PRIMARY KEY (OrderID, ContactID)
    );

    INSERT INTO OrderContacts (OrderID, ContactID, AssignedByUserID) VALUES 
        (1, 1, 1),
        (2, 2, 2),
        (3, 3, 3);
END
GO

-- Widok OrderDetails
/* 
Zastosowanie: Łączy dane zamówień, klientów i statusów w czytelną formę.
Dlaczego: Ułatwia szybki przegląd zleceń bez potrzeby pisania złożonych zapytań.
Korzyści: Przyspiesza pracę użytkowników operacyjnych i wspiera raportowanie.
*/
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'OrderDetails')
BEGIN
    EXEC('CREATE VIEW dbo.OrderDetails AS
    SELECT 
        o.OrderID, 
        o.OrderDate, 
        o.DeadlineDate, 
        o.Description, 
        os.StatusName AS Status,
        c.FirstName + '' '' + c.LastName AS ClientFullName,
        c.ClientID,
        u.Username AS AssignedToUsername
    FROM dbo.Orders o
    JOIN dbo.Clients c ON o.ClientID = c.ClientID
    JOIN dbo.OrderStatuses os ON o.StatusID = os.StatusID
    LEFT JOIN dbo.Users u ON o.AssignedToUserID = u.UserID;');
END
GO

-- Widok ClientSummary
/* 
Zastosowanie: Agreguje dane klientów, ich zamówienia i koszty w syntetyczny raport.
Dlaczego: Dostarcza menedżerom szybki obraz aktywności i rentowności klientów.
Korzyści: Ułatwia podejmowanie decyzji biznesowych bez konieczności analizy surowych danych.
*/
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'ClientSummary')
BEGIN
    EXEC('CREATE VIEW dbo.ClientSummary AS
    SELECT 
        c.ClientID,
        c.FirstName + '' '' + c.LastName AS ClientFullName,
        c.City,
        c.Country,
        COUNT(o.OrderID) AS TotalOrders,
        SUM(co.Amount) AS TotalCosts,
        u.Username AS ManagedByUsername
    FROM dbo.Clients c
    LEFT JOIN dbo.Orders o ON c.ClientID = o.ClientID
    LEFT JOIN dbo.Costs co ON c.ClientID = co.ClientID
    LEFT JOIN dbo.Users u ON c.ManagedByUserID = u.UserID
    GROUP BY c.ClientID, c.FirstName, c.LastName, c.City, c.Country, u.Username;');
END
GO