-- Better Tenant: RLS policies and triggers
-- Schema (tenants table, tenant_id columns) is managed by your ORM.

-- Better Tenant: trigger function for auto-populating tenant_id
CREATE OR REPLACE FUNCTION set_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenant_id IS NULL AND current_setting('app.current_tenant', true) IS NOT NULL THEN
    NEW.tenant_id := current_setting('app.current_tenant', true)::uuid;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Better Tenant: RLS for users
ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "users" FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rls_tenant_users" ON "users";
CREATE POLICY "rls_tenant_users" ON "users"
  FOR ALL
  USING (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  )
  WITH CHECK (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  );

DROP TRIGGER IF EXISTS set_tenant_id_trigger ON "users";
CREATE TRIGGER set_tenant_id_trigger
  BEFORE INSERT ON "users"
  FOR EACH ROW
  EXECUTE PROCEDURE set_tenant_id();

-- Better Tenant: RLS for projects
ALTER TABLE "projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects" FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rls_tenant_projects" ON "projects";
CREATE POLICY "rls_tenant_projects" ON "projects"
  FOR ALL
  USING (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  )
  WITH CHECK (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  );

DROP TRIGGER IF EXISTS set_tenant_id_trigger ON "projects";
CREATE TRIGGER set_tenant_id_trigger
  BEFORE INSERT ON "projects"
  FOR EACH ROW
  EXECUTE PROCEDURE set_tenant_id();

-- Better Tenant: RLS for categories
ALTER TABLE "categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "categories" FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rls_tenant_categories" ON "categories";
CREATE POLICY "rls_tenant_categories" ON "categories"
  FOR ALL
  USING (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  )
  WITH CHECK (
    (tenant_id)::text = current_setting('app.current_tenant', true)
    OR current_setting('app.bypass_rls', true) = 'true'
  );

DROP TRIGGER IF EXISTS set_tenant_id_trigger ON "categories";
CREATE TRIGGER set_tenant_id_trigger
  BEFORE INSERT ON "categories"
  FOR EACH ROW
  EXECUTE PROCEDURE set_tenant_id();
