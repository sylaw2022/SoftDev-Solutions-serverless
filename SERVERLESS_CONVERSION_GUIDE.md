# Serverless Conversion Guide

This guide outlines all the changes needed to convert this Next.js application from a traditional server-based architecture to a serverless architecture.

## Overview

**Current Architecture:** Traditional server (Render.com web service)
**Target Architecture:** Serverless (Vercel, AWS Lambda, or similar)

## Key Changes Required

### 1. Database Connection Pooling

**Problem:** Connection pools don't work well in serverless because:
- Each function invocation is isolated
- Connections can't be shared between invocations
- Cold starts create new connections each time

**Solution:** Use connection-per-request pattern or serverless-optimized connection pooling.

---

## Required Code Changes

### 1. Update `src/lib/database.ts`

Replace the persistent connection pool with a serverless-friendly approach:

```typescript
import { Pool, QueryResult, Client } from 'pg';

// Serverless-friendly database connection
// Don't use persistent pools in serverless - create connections per request
let globalPool: Pool | null = null;

// Get database connection (serverless-optimized)
export function getDatabase(): Pool {
  // In serverless, we need to handle connection pooling differently
  // Vercel and other platforms support connection pooling via external services
  // or we use a lightweight pool that reuses connections within the same execution context
  
  if (!globalPool) {
    const connectionString = process.env.DATABASE_URL || 
      process.env.POSTGRES_URL ||
      'postgresql://postgres:Sylaw1970@localhost:5433/postgres';

    const requiresSSL = connectionString.includes('render.com') || 
                        connectionString.includes('amazonaws.com') ||
                        connectionString.includes('vercel') ||
                        (process.env.NODE_ENV === 'production' && !connectionString.includes('localhost'));

    // For serverless, use smaller pool sizes
    // Each function invocation may get its own pool instance
    globalPool = new Pool({
      connectionString,
      ssl: requiresSSL ? { rejectUnauthorized: false } : false,
      // Serverless-optimized pool settings
      max: 1, // Maximum 1 connection per function invocation
      idleTimeoutMillis: 10000, // Shorter timeout
      connectionTimeoutMillis: 5000, // Faster timeout
      allowExitOnIdle: true, // Allow pool to close when idle
    });

    // Handle pool errors
    globalPool.on('error', (err: Error) => {
      console.error('[Database] Unexpected error on idle client', err);
    });
  }
  
  return globalPool;
}

// Serverless-friendly initialization
// Don't initialize on module load - initialize on first request
let isInitialized = false;
const initPromise: Promise<void> | null = null;

async function ensureDatabaseInitialized(): Promise<void> {
  if (isInitialized) return;
  
  if (initPromise) {
    await initPromise;
    return;
  }
  
  const init = async () => {
    try {
      const db = getDatabase();
      
      // Create users table
      await db.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          first_name VARCHAR(255) NOT NULL,
          last_name VARCHAR(255) NOT NULL,
          email VARCHAR(255) UNIQUE NOT NULL,
          company VARCHAR(255) NOT NULL,
          phone VARCHAR(50) NOT NULL,
          message TEXT DEFAULT '',
          email_sent BOOLEAN DEFAULT FALSE,
          email_sent_at TIMESTAMP,
          email_message_id VARCHAR(255),
          admin_notification_sent BOOLEAN DEFAULT FALSE,
          admin_notification_sent_at TIMESTAMP,
          admin_notification_message_id VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      await db.query(`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at)`);
      
      isInitialized = true;
      console.log('[Database] Database initialized successfully');
    } catch (error) {
      console.error('[Database] Error initializing database:', error);
      throw error;
    }
  };
  
  await init();
}

// Update UserRepository to ensure initialization
export class UserRepository {
  private db: Pool;

  constructor() {
    this.db = getDatabase();
  }

  // Ensure database is initialized before operations
  private async ensureInitialized() {
    await ensureDatabaseInitialized();
  }

  async createUser(userData: CreateUserData): Promise<User> {
    await this.ensureInitialized();
    // ... rest of the method stays the same
  }

  // Apply ensureInitialized() to all methods
  // ... (rest of methods)
}

// Close database connection (important for serverless)
export async function closeDatabase(): Promise<void> {
  if (globalPool) {
    await globalPool.end();
    globalPool = null;
    isInitialized = false;
    console.log('[Database] Database connection pool closed.');
  }
}
```

### Alternative: Use Vercel Postgres or Serverless Connection Pooling

For better performance on Vercel, use their managed Postgres with built-in connection pooling:

```typescript
// Use Vercel Postgres with @vercel/postgres
import { sql } from '@vercel/postgres';

// Or use PgBouncer connection pooling
// Connection string format: postgresql://user:pass@host:port/db?pgbouncer=true
```

---

### 2. Update `next.config.ts`

Add serverless-specific configuration:

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Enable serverless output
  output: 'standalone', // or remove for default serverless behavior on Vercel
  
  // Optimize for serverless
  experimental: {
    // Reduce bundle size
    optimizePackageImports: ['pg', '@vercel/postgres'],
  },
  
  // Environment variables that should be available at build time
  env: {
    DATABASE_URL: process.env.DATABASE_URL,
  },
};

export default nextConfig;
```

---

### 3. Create `vercel.json` (for Vercel deployment)

```json
{
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm ci",
  "framework": "nextjs",
  "regions": ["sin1"],
  "env": {
    "NODE_ENV": "production"
  },
  "functions": {
    "src/app/api/**/*.ts": {
      "maxDuration": 30
    }
  }
}
```

---

### 4. Update API Routes for Serverless

Add connection cleanup in API routes:

```typescript
// Example: src/app/api/register/route.ts
import { closeDatabase } from '@/lib/database';

export async function POST(request: NextRequest) {
  try {
    // ... your existing code
    return NextResponse.json({ success: true });
  } catch (error) {
    // ... error handling
  } finally {
    // In serverless, optionally close connections
    // Note: Vercel handles this automatically, but explicit cleanup is good practice
    // await closeDatabase(); // Uncomment if needed
  }
}
```

---

### 5. Remove Persistent File System Dependencies

**Current Issue:** SQLite file storage won't work in serverless (ephemeral filesystem)

**Solution:** Already using PostgreSQL (good!), but ensure no file system writes:

- ✅ Already using PostgreSQL (no changes needed)
- ❌ Remove any `fs.writeFile`, `fs.appendFile` operations
- ❌ Use object storage (S3, Vercel Blob) for file uploads

---

### 6. Update Environment Variables

**For Vercel:**
1. Go to Vercel Dashboard → Project → Settings → Environment Variables
2. Add:
   - `DATABASE_URL` - Your PostgreSQL connection string
   - `NODE_ENV=production`
   - Any other required variables

**For AWS Lambda:**
- Use AWS Systems Manager Parameter Store or Secrets Manager
- Or set in Lambda function configuration

---

### 7. Update `package.json` Scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start", // Remove for serverless (not needed)
    "deploy": "vercel", // Add for Vercel
    "deploy:prod": "vercel --prod" // Add for production
  }
}
```

---

### 8. Remove `render.yaml` (or keep for reference)

Serverless platforms don't use `render.yaml`. Instead:

- **Vercel:** Uses `vercel.json` and auto-detects Next.js
- **AWS:** Uses `serverless.yml` or SAM templates
- **Netlify:** Uses `netlify.toml`

---

## Deployment Platform Options

### Option 1: Vercel (Recommended for Next.js)

**Pros:**
- Built-in Next.js optimization
- Automatic serverless function creation
- Edge network
- Free tier available

**Steps:**
1. Install Vercel CLI: `npm i -g vercel`
2. Run: `vercel`
3. Connect GitHub repository
4. Set environment variables in dashboard
5. Deploy: `vercel --prod`

**Database Options:**
- Vercel Postgres (managed, with connection pooling)
- External PostgreSQL (Render.com, Supabase, etc.)

### Option 2: AWS Lambda + API Gateway

**Pros:**
- Enterprise-grade
- Pay-per-use
- Highly scalable

**Steps:**
1. Use Serverless Framework or AWS SAM
2. Configure `serverless.yml`
3. Deploy with `serverless deploy`

### Option 3: Netlify

**Pros:**
- Easy deployment
- Good Next.js support
- Free tier

**Steps:**
1. Connect GitHub repository
2. Configure `netlify.toml`
3. Set environment variables
4. Deploy automatically on push

---

## Database Connection Pooling Solutions

### Option A: External Connection Pooler (Recommended)

Use PgBouncer or similar:

```
# Connection string with PgBouncer
postgresql://user:pass@pgbouncer-host:6432/db?pgbouncer=true
```

### Option B: Vercel Postgres

```typescript
import { sql } from '@vercel/postgres';

// Automatically handles connection pooling
const result = await sql`SELECT * FROM users WHERE id = ${id}`;
```

### Option C: Supabase

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);
```

---

## Testing Serverless Locally

### Vercel CLI

```bash
# Install
npm i -g vercel

# Run locally (simulates serverless environment)
vercel dev
```

### Serverless Framework

```bash
# Install
npm i -g serverless

# Run locally
serverless offline
```

---

## Migration Checklist

- [ ] Update `src/lib/database.ts` for serverless connection handling
- [ ] Update `next.config.ts` with serverless configuration
- [ ] Create `vercel.json` (or platform-specific config)
- [ ] Remove persistent file system operations
- [ ] Update environment variables
- [ ] Test database connections in serverless environment
- [ ] Update deployment documentation
- [ ] Remove `render.yaml` or mark as deprecated
- [ ] Update CI/CD pipeline for serverless deployment
- [ ] Test cold start performance
- [ ] Monitor connection pool usage
- [ ] Set up database connection pooling (PgBouncer, Vercel Postgres, etc.)

---

## Performance Considerations

### Cold Starts
- First request after inactivity may be slower
- Keep functions warm with scheduled pings (if needed)
- Use edge functions for static content

### Connection Limits
- Serverless functions may hit database connection limits
- Use connection pooling service (PgBouncer, Vercel Postgres)
- Limit concurrent connections per function

### Timeout Limits
- Vercel: 10s (Hobby), 60s (Pro)
- AWS Lambda: 15 minutes (configurable)
- Netlify: 26 seconds

---

## Cost Comparison

### Serverless (Vercel)
- Free tier: 100GB bandwidth, unlimited requests
- Pro: $20/month per user
- Pay for what you use

### Traditional Server (Render.com)
- Free tier: Spins down after 15 min inactivity
- Paid: $7-25/month for always-on

---

## Rollback Plan

If you need to rollback to traditional server:

1. Revert `src/lib/database.ts` to use persistent pool
2. Restore `render.yaml`
3. Deploy to Render.com
4. Update environment variables

---

## Additional Resources

- [Vercel Next.js Documentation](https://vercel.com/docs)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Serverless Database Connection Patterns](https://www.prisma.io/dataguide/serverless/introduction)
- [Vercel Postgres](https://vercel.com/docs/storage/vercel-postgres)

---

## Support

For questions or issues during migration, refer to:
- Platform-specific documentation
- Next.js serverless deployment guides
- Database provider connection pooling guides

