-- Przełączenie na master do tworzenia loginów
/* 
Zastosowanie: Przełączenie na bazę master umożliwia zarządzanie loginami na poziomie serwera.
Dlaczego: Loginy muszą być tworzone w kontekście master, aby miały dostęp do całego serwera i mogły być mapowane na użytkowników w bazach.
Korzyści: Umożliwia centralne zarządzanie dostępem i zapewnia spójność uprawnień na poziomie serwera.
*/
USE master;
GO

-- Tworzenie loginów
/* 
Zastosowanie: Tworzy loginy dla administratora i wyszukiwacza z tymczasowymi hasłami wymagającymi zmiany.
Dlaczego: Umożliwia bezpieczne uwierzytelnianie użytkowników na poziomie serwera, zgodne z rolami w systemie.
Korzyści: Opcja MUST_CHANGE wymusza zmianę hasła przy pierwszym logowaniu, co zwiększa bezpieczeństwo, a CHECK_EXPIRATION pozwala kontrolować ważność haseł.
*/
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'login_treasure_hunter_db_admin')
BEGIN
    CREATE LOGIN login_treasure_hunter_db_admin WITH PASSWORD = 'TempAdmin123!' MUST_CHANGE, CHECK_EXPIRATION = ON;
END

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'login_treasure_hunter_db_searcher')
BEGIN
    CREATE LOGIN login_treasure_hunter_db_searcher WITH PASSWORD = 'TempSearcher123!' MUST_CHANGE, CHECK_EXPIRATION = ON;
END
GO

-- Przełączenie na bazę treasure_hunter_db
/* 
Zastosowanie: Przełączenie na bazę treasure_hunter_db pozwala na tworzenie użytkowników i ról w jej kontekście.
Dlaczego: Użytkownicy i ich uprawnienia muszą być definiowane w konkretnej bazie, aby działały w jej obrębie.
Korzyści: Umożliwia precyzyjne zarządzanie dostępem ograniczonym do tej bazy, co zwiększa bezpieczeństwo i porządek.
*/
USE treasure_hunter_db;
GO

-- Tworzenie użytkowników
/* 
Zastosowanie: Tworzy użytkowników w bazie powiązanych z loginami serwera.
Dlaczego: Umożliwia mapowanie loginów na użytkowników bazy, co jest konieczne do nadawania uprawnień w treasure_hunter_db.
Korzyści: Zapewnia, że każdy login ma odpowiednik w bazie, co ułatwia zarządzanie dostępem i rolami.
*/
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'treasure_hunter_db_admin')
BEGIN
    CREATE USER treasure_hunter_db_admin FOR LOGIN login_treasure_hunter_db_admin;
END

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'treasure_hunter_db_searcher')
BEGIN
    CREATE USER treasure_hunter_db_searcher FOR LOGIN login_treasure_hunter_db_searcher;
END
GO

-- Role i uprawnienia dla administratora
/* 
Zastosowanie: Tworzy rolę administratora z pełną kontrolą nad bazą i przypisuje do niej użytkownika.
Dlaczego: Administrator potrzebuje nieograniczonego dostępu, aby zarządzać wszystkimi obiektami i danymi w bazie.
Korzyści: Upraszcza zarządzanie uprawnieniami, dając pełną kontrolę w jednym miejscu, co przyspiesza administrację i reagowanie na problemy.
*/
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_treasure_hunter_db_admin' AND type = 'R')
BEGIN
    CREATE ROLE role_treasure_hunter_db_admin;
    GRANT CONTROL ON DATABASE::treasure_hunter_db TO role_treasure_hunter_db_admin;
END

IF NOT EXISTS (SELECT * FROM sys.database_role_members 
               WHERE role_principal_id = DATABASE_PRINCIPAL_ID('role_treasure_hunter_db_admin') 
               AND member_principal_id = DATABASE_PRINCIPAL_ID('treasure_hunter_db_admin'))
BEGIN
    ALTER ROLE role_treasure_hunter_db_admin ADD MEMBER treasure_hunter_db_admin;
END
GO

-- Role i uprawnienia dla wyszukiwacza
/* 
Zastosowanie: Tworzy rolę dla wyszukiwacza z ograniczonymi uprawnieniami do odczytu kluczowych tabel i widoków.
Dlaczego: Wyszukiwacz potrzebuje dostępu tylko do danych operacyjnych, bez możliwości ich modyfikacji czy dostępu do poufnych tabel (np. Users).
Korzyści: Ograniczenie uprawnień zwiększa bezpieczeństwo danych, a precyzyjne nadanie praw do pełnotekstowych katalogów wspiera efektywne wyszukiwanie.
*/
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_treasure_hunter_db_searcher' AND type = 'R')
BEGIN
    CREATE ROLE role_treasure_hunter_db_searcher;
    GRANT SELECT ON dbo.Clients TO role_treasure_hunter_db_searcher;
    GRANT SELECT ON dbo.Orders TO role_treasure_hunter_db_searcher;
    GRANT SELECT ON dbo.Contacts TO role_treasure_hunter_db_searcher;
    GRANT SELECT ON dbo.Notes TO role_treasure_hunter_db_searcher;
    GRANT SELECT ON dbo.OrderDetails TO role_treasure_hunter_db_searcher;
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Users TO role_treasure_hunter_db_searcher;
    
    -- Opcjonalne: uprawnienia do katalogów pełnotekstowych
    GRANT REFERENCES ON FULLTEXT CATALOG::ClientsFullTextCatalog TO role_treasure_hunter_db_searcher;
    GRANT REFERENCES ON FULLTEXT CATALOG::OrdersFullTextCatalog TO role_treasure_hunter_db_searcher;
    GRANT REFERENCES ON FULLTEXT CATALOG::NotesFullTextCatalog TO role_treasure_hunter_db_searcher;
END

IF NOT EXISTS (SELECT * FROM sys.database_role_members 
               WHERE role_principal_id = DATABASE_PRINCIPAL_ID('role_treasure_hunter_db_searcher') 
               AND member_principal_id = DATABASE_PRINCIPAL_ID('treasure_hunter_db_searcher'))
BEGIN
    ALTER ROLE role_treasure_hunter_db_searcher ADD MEMBER treasure_hunter_db_searcher;
END
GO

-- Audyt dostępu do danych osobowych
/* 
Zastosowanie: Przełączenie na master umożliwia konfigurację audytu na poziomie serwera.
Dlaczego: Audyt serwera musi być tworzony w master, aby obejmował zdarzenia zarówno serwerowe, jak i bazodanowe.
Korzyści: Centralizacja audytu ułatwia monitorowanie i zapewnia spójność logów w jednym miejscu.
*/
USE master;
GO

-- Wyłączenie i usunięcie istniejącego audytu, jeśli istnieje
/* 
Zastosowanie: Usuwa poprzedni audyt, jeśli istnieje, aby uniknąć konfliktów.
Dlaczego: Zapewnia czystą konfigurację nowego audytu bez wpływu starych ustawień.
Korzyści: Umożliwia bezpieczne ponowne zdefiniowanie audytu z aktualnymi wymaganiami.
*/
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'TreasureHunterAudit')
BEGIN
    ALTER SERVER AUDIT TreasureHunterAudit WITH (STATE = OFF);
    DROP SERVER AUDIT TreasureHunterAudit;
END
GO

-- Definiowanie ścieżki audytu
/* 
Zastosowanie: Tworzy folder do przechowywania plików audytu.
Dlaczego: Pliki audytu muszą być zapisywane w określonej lokalizacji na serwerze, aby były dostępne do analizy.
Korzyści: Użycie xp_create_subdir automatyzuje tworzenie katalogu, co ułatwia wdrożenie na różnych serwerach.
*/
DECLARE @AuditPath NVARCHAR(256) = 'C:\temp\treasure_hunter_db\Audit\';
EXEC master.dbo.xp_create_subdir @AuditPath;

-- Tworzenie Server Audit, jeśli nie istnieje
/* 
Zastosowanie: Tworzy audyt serwera zapisujący zdarzenia do pliku.
Dlaczego: Umożliwia rejestrowanie kluczowych akcji (np. logowania, dostępu do danych) w celu monitorowania bezpieczeństwa.
Korzyści: Opcja ON_FAILURE = CONTINUE zapewnia ciągłość działania systemu nawet w przypadku problemów z zapisem, co zwiększa niezawodność.
*/
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'TreasureHunterAudit')
BEGIN
    CREATE SERVER AUDIT TreasureHunterAudit
    TO FILE (FILEPATH = 'C:\temp\treasure_hunter_db\Audit\')
    WITH (ON_FAILURE = CONTINUE);
END

-- Włączenie audytu, jeśli nie jest aktywny
/* 
Zastosowanie: Aktywuje audyt, jeśli został utworzony, ale nie włączony.
Dlaczego: Bez włączenia audyt nie będzie rejestrował zdarzeń, co czyni go bezużytecznym.
Korzyści: Zapewnia, że monitorowanie zaczyna się natychmiast po konfiguracji.
*/
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'TreasureHunterAudit' AND is_state_enabled = 0)
BEGIN
    ALTER SERVER AUDIT TreasureHunterAudit WITH (STATE = ON);
END
GO

USE treasure_hunter_db;
GO

-- Tworzenie Database Audit Specification, jeśli nie istnieje
/* 
Zastosowanie: Definiuje audyt działań na tabelach z danymi osobowymi i operacyjnymi.
Dlaczego: Monitoruje dostęp i modyfikacje danych wrażliwych (np. Clients, Orders) przez użytkowników, co jest kluczowe dla zgodności z przepisami.
Korzyści: Umożliwia śledzenie, kto i kiedy uzyskiwał dostęp do danych, co zwiększa bezpieczeństwo i pozwala na szybką reakcję na nieautoryzowane działania.
*/
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'ClientDataAccess')
BEGIN
    CREATE DATABASE AUDIT SPECIFICATION ClientDataAccess
    FOR SERVER AUDIT TreasureHunterAudit
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Clients BY treasure_hunter_db_searcher, treasure_hunter_db_admin),  
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Contacts BY treasure_hunter_db_searcher, treasure_hunter_db_admin),  
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Notes BY treasure_hunter_db_searcher, treasure_hunter_db_admin),  
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Costs BY treasure_hunter_db_searcher, treasure_hunter_db_admin),  
    ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Orders BY treasure_hunter_db_admin)  
    WITH (STATE = ON);
END
ELSE
BEGIN
    -- Włączenie specyfikacji, jeśli istnieje, ale jest wyłączona
    IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'ClientDataAccess' AND is_state_enabled = 0)
    BEGIN
        ALTER DATABASE AUDIT SPECIFICATION ClientDataAccess WITH (STATE = ON);
    END
END
GO

-- Audyt logowania do serwera SQL
/* 
Zastosowanie: Przełączenie na master umożliwia konfigurację audytu logowań na poziomie serwera.
Dlaczego: Logowania są zdarzeniami serwerowymi, więc muszą być monitorowane w master.
Korzyści: Umożliwia śledzenie wszystkich prób logowania w jednym miejscu, co ułatwia zarządzanie bezpieczeństwem.
*/
USE master;
GO

-- Tworzenie Server Audit Specification, jeśli nie istnieje
/* 
Zastosowanie: Rejestruje udane i nieudane próby logowania do serwera SQL.
Dlaczego: Pozwala monitorować, kto próbuje uzyskać dostęp do systemu, co jest istotne dla wykrywania nieautoryzowanych działań.
Korzyści: Zwiększa bezpieczeństwo poprzez możliwość analizy wzorców logowania i szybkiego reagowania na podejrzane próby.
*/
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'LoginAudit')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION LoginAudit
    FOR SERVER AUDIT TreasureHunterAudit
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (FAILED_LOGIN_GROUP)
    WITH (STATE = ON);
END
ELSE
BEGIN
    -- Włączenie specyfikacji, jeśli istnieje, ale jest wyłączona
    IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'LoginAudit' AND is_state_enabled = 0)
    BEGIN
        ALTER SERVER AUDIT SPECIFICATION LoginAudit WITH (STATE = ON);
    END
END
GO