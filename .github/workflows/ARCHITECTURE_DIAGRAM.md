# CI/CD Architecture Diagram

## Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NEXA PROJECT REPOSITORY                           │
│                         github.com/[owner]/nexa                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                     ┌───────────────┴───────────────┐
                     │ Developer pushes to GitHub     │
                     │ (main or android1 branch)      │
                     └───────────────┬───────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
        │                            │                            │
┌───────▼────────┐         ┌─────────▼────────┐        ┌─────────▼────────┐
│ Changed Files: │         │ Changed Files:   │        │ Changed Files:   │
│   backend/**   │         │   lib/**,web/** │        │   *.md, other    │
└───────┬────────┘         └─────────┬────────┘        └─────────┬────────┘
        │                            │                            │
        │                            │                            │
┌───────▼────────────────────────────────────────────────────────▼────────┐
│                    GITHUB ACTIONS WORKFLOW ENGINE                       │
└────────┬────────────────────────────────────┬────────────────────────┬─┘
         │                                    │                        │
         │                                    │                        │
    ┌────▼─────┐                      ┌──────▼──────┐                │
    │ deploy.  │                      │flutter-web- │                │
    │   yml    │                      │ deploy.yml  │                │
    └────┬─────┘                      └──────┬──────┘                │
         │                                    │                   No workflow
         │                                    │                   triggered
         │                                    │
         │                                    │
┌────────▼────────┐              ┌────────────▼─────────────┐
│  BACKEND PIPELINE              │  FRONTEND PIPELINE       │
│  (Express.js)   │              │  (Flutter Web)           │
└─────────────────┘              └──────────────────────────┘
```

## Backend Pipeline Details

```
┌──────────────────────────────────────────────────────────────────┐
│                      BACKEND PIPELINE                            │
│                    (deploy.yml)                                  │
└──────────────────────────────────────────────────────────────────┘
                             │
                             │
                    ┌────────▼─────────┐
                    │  Job 1:          │
                    │  test-and-build  │
                    │  (ubuntu-latest) │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐      ┌──────▼──────┐      ┌─────▼─────┐
   │ Setup    │      │ Run type    │      │ Run tests │
   │ Node.js  │ ───> │ check       │ ───> │ npm test  │
   │ npm ci   │      │ (npm lint)  │      │           │
   └──────────┘      └─────────────┘      └─────┬─────┘
                                                 │
                                          ┌──────▼──────┐
                                          │ Build       │
                                          │ TypeScript  │
                                          │ (npm build) │
                                          └──────┬──────┘
                                                 │
                                          ┌──────▼──────┐
                                          │ Upload      │
                                          │ artifact    │
                                          │ (dist/)     │
                                          └──────┬──────┘
                                                 │
                    ┌────────────────────────────┘
                    │
           ┌────────▼─────────┐
           │  Job 2:          │
           │  deploy          │
           │  (ubuntu-latest) │
           └────────┬─────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼─────┐ ┌──▼──────┐ ┌──▼──────────┐
   │ Checkout │ │ Sanity  │ │ SSH Deploy  │
   │ repo     │ │ check   │ │ (appleboy/  │
   │          │ │ inputs  │ │ ssh-action) │
   └──────────┘ └─────────┘ └──────┬──────┘
                                   │
                                   │ SSH Connection
                                   │ User: ${{ vars.SERVER_USER }}
                                   │ Host: ${{ vars.SERVER_HOST }}
                                   │ Key:  ${{ secrets.SERVER_SSH_KEY }}
                                   │
                          ┌────────▼─────────┐
                          │   LINODE VPS     │
                          │  198.58.111.243  │
                          │                  │
                          │  Runs:           │
                          │  cd ~            │
                          │  ./deploy.sh     │
                          │                  │
                          │  Express.js API  │
                          │  Running on :3000│
                          └──────────────────┘
```

## Frontend Pipeline Details

```
┌──────────────────────────────────────────────────────────────────────┐
│                      FRONTEND PIPELINE                               │
│                 (flutter-web-deploy.yml)                             │
└──────────────────────────────────────────────────────────────────────┘
                                  │
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
          ┌───────▼────────┐ ┌───▼────────┐ ┌───▼─────────┐
          │ Job 1:         │ │ Job 3:     │ │ Job 4:      │
          │ analyze-and-   │ │ deploy-    │ │ deploy-     │
          │ test           │ │ cloudflare │ │ preview     │
          └───────┬────────┘ └───┬────────┘ └───┬─────────┘
                  │              │ (depends    │ (depends on
                  │              │  on Job 2)  │  Job 2)
                  │              │             │
         ┌────────┼────────┐     │             │ (runs on PRs)
         │        │        │     │             │
    ┌────▼──┐ ┌──▼───┐ ┌──▼───┐ │             │
    │Setup  │ │Code  │ │ Run  │ │             │
    │Flutter│ │gen.  │ │tests │ │             │
    │3.9.0  │ │build_│ │      │ │             │
    │       │ │runner│ │      │ │             │
    └───────┘ └──┬───┘ └──────┘ │             │
                 │               │             │
          ┌──────▼──────┐        │             │
          │ flutter     │        │             │
          │ analyze     │        │             │
          │ (FAIL FAST) │        │             │
          └──────┬──────┘        │             │
                 │ ✅ Pass       │             │
                 │               │             │
          ┌──────▼──────┐        │             │
          │ flutter     │        │             │
          │ test        │        │             │
          │ (FAIL FAST) │        │             │
          └──────┬──────┘        │             │
                 │ ✅ Pass       │             │
                 │               │             │
          ┌──────▼──────┐        │             │
          │ Upload      │        │             │
          │ coverage    │        │             │
          └──────┬──────┘        │             │
                 │               │             │
                 │ ✅ Success    │             │
                 │               │             │
          ┌──────▼────────┐      │             │
          │ Job 2:        │      │             │
          │ build-web     │      │             │
          │ (ubuntu)      │      │             │
          └──────┬────────┘      │             │
                 │               │             │
    ┌────────────┼────────────┐  │             │
    │            │            │  │             │
┌───▼────┐ ┌────▼─────┐ ┌────▼──▼───┐         │
│ Setup  │ │ flutter  │ │ Verify    │         │
│Flutter │ │ build    │ │ build/web/│         │
│pub get │ │ web      │ │ index.html│         │
│        │ │ --release│ │ exists    │         │
└────────┘ └────┬─────┘ └─────┬─────┘         │
                │             │               │
         ┌──────▼─────────────▼──┐            │
         │ Upload build artifact │            │
         │ (build/web/)          │            │
         └──────┬────────────────┘            │
                │                             │
                │ ✅ Build success            │
                │                             │
                ├─────────────────────────────┤
                │                             │
       ┌────────▼─────────┐          ┌────────▼─────────┐
       │ Job 3:           │          │ Job 4:           │
       │ deploy-          │          │ deploy-preview   │
       │ cloudflare       │          │ (PR only)        │
       │ (push only)      │          │                  │
       └────────┬─────────┘          └────────┬─────────┘
                │                             │
    ┌───────────┼───────────┐     ┌───────────┼─────────┐
    │           │           │     │           │         │
┌───▼────┐ ┌────▼─────┐ ┌──▼────┐│      Same steps    │
│Download│ │ Deploy   │ │Deploy ││      as Job 3      │
│artifact│ │ via      │ │summary││      but with      │
│        │ │ Wrangler │ │       ││      --branch flag │
└────────┘ └────┬─────┘ └───────┘│                    │
                │                 └────────┬───────────┘
                │                          │
                │ Uses:                    │
                │ - CLOUDFLARE_API_TOKEN   │
                │ - CLOUDFLARE_ACCOUNT_ID  │
                │                          │
       ┌────────▼──────────┐     ┌─────────▼──────────┐
       │ CLOUDFLARE PAGES  │     │ CLOUDFLARE PAGES   │
       │ (Production)      │     │ (Preview)          │
       │                   │     │                    │
       │ Project: nexa-web │     │ Branch: feature-x  │
       │ URL:              │     │ URL:               │
       │ app.nexa          │     │ feature-x.nexa-web │
       │ pymesoft.com      │     │ .pages.dev         │
       └───────────────────┘     └────────────────────┘
```

## Quality Gates Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CODE PUSHED TO GITHUB                    │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │ GATE 1:        │
                    │ Static Analysis│
                    └───────┬────────┘
                            │
                    ┌───────▼────────────────────────┐
                    │ Backend: npm run lint          │
                    │ Frontend: flutter analyze      │
                    └───────┬────────────────────────┘
                            │
                   ❌ FAIL  │  ✅ PASS
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼─────┐       ┌────▼────────┐        │
   │ STOP     │       │ GATE 2:     │        │
   │ Deploy   │       │ Unit Tests  │        │
   │ blocked  │       └────┬────────┘        │
   └──────────┘            │                 │
                   ┌───────▼────────────────────────┐
                   │ Backend: npm test              │
                   │ Frontend: flutter test         │
                   └───────┬────────────────────────┘
                           │
                  ❌ FAIL  │  ✅ PASS
       ┌──────────────────┼──────────────────┐
       │                  │                  │
  ┌────▼─────┐       ┌────▼────────┐        │
  │ STOP     │       │ GATE 3:     │        │
  │ Deploy   │       │ Build       │        │
  │ blocked  │       └────┬────────┘        │
  └──────────┘            │                 │
                  ┌───────▼────────────────────────┐
                  │ Backend: npm run build         │
                  │ Frontend: flutter build web    │
                  └───────┬────────────────────────┘
                          │
                 ❌ FAIL  │  ✅ PASS
      ┌──────────────────┼──────────────────┐
      │                  │                  │
 ┌────▼─────┐       ┌────▼────────┐        │
 │ STOP     │       │ GATE 4:     │        │
 │ Deploy   │       │ Build       │        │
 │ blocked  │       │ Verification│        │
 └──────────┘       └────┬────────┘        │
                         │                 │
                 ┌───────▼────────────────────────┐
                 │ Backend: artifact exists       │
                 │ Frontend: index.html exists    │
                 └───────┬────────────────────────┘
                         │
                ❌ FAIL  │  ✅ PASS
     ┌──────────────────┼──────────────────┐
     │                  │                  │
┌────▼─────┐       ┌────▼──────────────┐  │
│ STOP     │       │ ALL GATES PASSED  │  │
│ Deploy   │       │                   │  │
│ blocked  │       │ 🚀 DEPLOY!        │  │
└──────────┘       └────┬──────────────┘  │
                        │                 │
          ┌─────────────┼─────────────┐   │
          │             │             │   │
     ┌────▼─────┐  ┌────▼─────┐      │   │
     │ Backend  │  │ Frontend │      │   │
     │ Deploy to│  │ Deploy to│      │   │
     │ Linode   │  │Cloudflare│      │   │
     └──────────┘  └──────────┘      │   │
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   DEVELOPMENT WORKFLOW                      │
└─────────────────────────────────────────────────────────────┘

Developer's Machine
┌──────────────────┐
│ 1. Write code    │
│ 2. Test locally  │      git push
│    - flutter test│ ─────────────> GitHub Repository
│    - npm test    │                └──┬──────────────┘
│ 3. git commit    │                   │
└──────────────────┘                   │ webhook trigger
                                       │
                                       ▼
                          ┌────────────────────┐
                          │ GitHub Actions     │
                          │ Workflow Engine    │
                          └────────┬───────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────┐  ┌──────────┐  ┌──────────┐
          │ Analyze     │  │ Test     │  │ Build    │
          │ Code        │  │ Code     │  │ Code     │
          └─────────────┘  └──────────┘  └─────┬────┘
                                               │
                                    ┌──────────┼─────────┐
                                    │          │         │
                                    ▼          ▼         ▼
                         ┌──────────────┐  ┌────────────────┐
                         │ Deploy to    │  │ Deploy to      │
                         │ Linode VPS   │  │ Cloudflare     │
                         │              │  │ Pages          │
                         └──────┬───────┘  └────────┬───────┘
                                │                   │
                                ▼                   ▼
                    ┌────────────────────┐  ┌──────────────┐
                    │ Backend API        │  │ Frontend Web │
                    │ 198.58.111.243     │  │ app.nexa     │
                    │ :3000              │  │ pymesoft.com │
                    └────────┬───────────┘  └──────┬───────┘
                             │                     │
                             │  HTTP API Calls     │
                             │<────────────────────┤
                             │                     │
                             │  JSON Responses     │
                             │─────────────────────>
                             │                     │
                                                   │
                                                   ▼
                                           ┌───────────────┐
                                           │ End Users     │
                                           │ (Browsers)    │
                                           └───────────────┘
```

## Secrets and Configuration

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECRETS MANAGEMENT                           │
└─────────────────────────────────────────────────────────────────┘

GitHub Repository Secrets
┌─────────────────────────────────────────────┐
│ Settings → Secrets and variables → Actions  │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
┌───────▼──────┐    │    ┌──────▼──────────────────┐
│ Backend      │    │    │ Frontend                │
│ Secrets      │    │    │ Secrets                 │
├──────────────┤    │    ├─────────────────────────┤
│ SERVER_SSH_  │    │    │ CLOUDFLARE_API_TOKEN    │
│ KEY          │    │    │ CLOUDFLARE_ACCOUNT_ID   │
└──────────────┘    │    └─────────────────────────┘
                    │
                    │ injected into workflows
                    ▼
        ┌───────────────────────┐
        │ GitHub Actions Runner │
        │ (ubuntu-latest)       │
        └───────────┬───────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌────────┐
   │Backend │  │Frontend│  │Preview │
   │Deploy  │  │Deploy  │  │Deploy  │
   └────────┘  └────────┘  └────────┘


Cloudflare Pages Environment Variables
┌──────────────────────────────────────────────┐
│ Dashboard → Pages → nexa-web → Settings     │
│ → Environment variables → Production         │
└──────────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌────────┐   ┌──────────┐   ┌──────────┐
│API     │   │Google    │   │Apple     │
│Config  │   │OAuth     │   │Sign In   │
├────────┤   ├──────────┤   ├──────────┤
│API_    │   │GOOGLE_   │   │APPLE_    │
│BASE_   │   │CLIENT_   │   │SERVICE_  │
│URL     │   │ID_WEB    │   │ID        │
└────────┘   └──────────┘   └──────────┘
     │            │              │
     └────────────┼──────────────┘
                  │
                  │ Injected at build time
                  │ via --dart-define
                  ▼
         ┌─────────────────┐
         │ Flutter Web App │
         │ (build/web)     │
         └─────────────────┘
```

## Timeline View

```
┌─────────────────────────────────────────────────────────────────┐
│         TYPICAL DEPLOYMENT TIMELINE (Frontend)                  │
└─────────────────────────────────────────────────────────────────┘

00:00  Developer pushes code to android1 branch
       │
       ▼
00:05  GitHub webhook triggers flutter-web-deploy.yml
       │
       ▼
00:10  Job 1 starts: analyze-and-test
       ├─ Setup Flutter SDK (cached, 30s)
       ├─ Install dependencies (cached, 20s)
       ├─ Run build_runner (1 min)
       ├─ Run flutter analyze (45s)
       └─ Run flutter test (1 min)
       │
       ▼
03:30  Job 1 completes ✅
       │
       ▼
03:35  Job 2 starts: build-web
       ├─ Setup Flutter SDK (cached, 20s)
       ├─ Install dependencies (cached, 15s)
       ├─ Run build_runner (1 min)
       ├─ Build web release (3 min)
       ├─ Verify build output (5s)
       └─ Upload artifacts (30s)
       │
       ▼
08:15  Job 2 completes ✅
       │
       ▼
08:20  Job 3 starts: deploy-cloudflare
       ├─ Checkout repo (10s)
       ├─ Download artifacts (15s)
       └─ Deploy to Cloudflare (1 min)
       │
       ▼
09:45  Job 3 completes ✅
       │
       ▼
09:50  Deployment live at app.nexapymesoft.com
       │
       ▼
10:00  CDN propagation complete (global)

TOTAL TIME: ~10 minutes
```

## Architecture Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│              BACKEND vs FRONTEND ARCHITECTURE                   │
└─────────────────────────────────────────────────────────────────┘

Backend (Stateful)                 Frontend (Stateless)
┌─────────────────┐                ┌─────────────────┐
│ Express.js API  │                │ Flutter Web App │
│ (Node.js)       │                │ (Dart)          │
└────────┬────────┘                └────────┬────────┘
         │                                  │
    ┌────▼─────┐                       ┌────▼─────┐
    │ Database │                       │ Static   │
    │ Sessions │                       │ Files    │
    │ WebSocket│                       │ (HTML/JS)│
    └────┬─────┘                       └────┬─────┘
         │                                  │
    ┌────▼──────┐                      ┌────▼──────┐
    │ Single    │                      │ CDN       │
    │ Server    │                      │ Global    │
    │ (Linode)  │                      │ Edge      │
    │           │                      │ Servers   │
    │ Limited   │                      │           │
    │ Bandwidth │                      │ Unlimited │
    │           │                      │ Bandwidth │
    │ Manual    │                      │           │
    │ Scaling   │                      │ Auto      │
    │           │                      │ Scaling   │
    └───────────┘                      └───────────┘
```

---

**Document Version**: 1.0.0
**Last Updated**: October 24, 2025
**Maintained By**: DevOps Team

**Legend**:
- ✅ = Success/Pass
- ❌ = Failure/Block
- 🚀 = Deployment
- │, ▼, ─, ┌, └, ├, ┤ = Flow connectors
