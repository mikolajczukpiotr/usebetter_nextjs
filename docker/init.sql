-- Create a non-superuser role for the app.
-- Superusers bypass RLS, so the app must connect as a regular user.
CREATE USER app_user WITH PASSWORD 'app_password';

-- Database-level privileges (script runs in usebetter via POSTGRES_DB)
GRANT CONNECT ON DATABASE usebetter TO app_user;
GRANT CREATE ON DATABASE usebetter TO app_user;

-- Schema-level privileges
GRANT USAGE, CREATE ON SCHEMA public TO app_user;

-- Ensure app_user gets privileges on tables/sequences created by Prisma migrations
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;
