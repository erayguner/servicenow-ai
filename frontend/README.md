# AI Research Assistant - Frontend

Next.js-based frontend for the AI Research Assistant with conversational UI and real-time interaction capabilities.

## Overview

This is a modern Next.js 15 application providing a user-friendly interface for interacting with the AI Research Assistant backend. Built with React 19, TypeScript, and Tailwind CSS.

## Technology Stack

- **Framework**: Next.js 15.4.7 (App Router)
- **UI Library**: React 19.0.0
- **Styling**: Tailwind CSS 4.1.17
- **Language**: TypeScript 5.7.3
- **HTTP Client**: Axios 1.7.9
- **Markdown Rendering**: react-markdown 9.0.1
- **Utilities**: clsx, date-fns

## Project Structure

```
frontend/
├── app/                    # Next.js app directory (pages and layouts)
├── components/             # Reusable React components
├── lib/                    # Utility functions and helpers
├── public/                 # Static assets
├── .env.example            # Environment variables template
├── Dockerfile              # Container configuration
├── next.config.js          # Next.js configuration
├── tailwind.config.js      # Tailwind CSS configuration
└── tsconfig.json           # TypeScript configuration
```

## Prerequisites

- Node.js >= 20.0.0
- npm or yarn package manager

## Getting Started

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env.local

# Edit with your backend API URL
# NEXT_PUBLIC_API_URL=http://localhost:8080
```

### 3. Run Development Server

```bash
npm run dev
```

The application will be available at http://localhost:3000

### 4. Build for Production

```bash
npm run build
npm start
```

## Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build production-optimized bundle |
| `npm start` | Start production server |
| `npm run lint` | Run ESLint for code quality checks |

## Environment Variables

Create a `.env.local` file based on `.env.example`:

```bash
# Backend API endpoint
NEXT_PUBLIC_API_URL=https://your-backend-api.example.com

# Optional: Enable analytics
NEXT_PUBLIC_ANALYTICS_ID=your-analytics-id
```

## Docker Deployment

### Build Container Image

```bash
docker build -t ai-research-assistant-frontend:latest .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://backend:8080 \
  ai-research-assistant-frontend:latest
```

## Cloud Deployment

### Deploy to Cloud Run (GCP)

The frontend is designed to be deployed alongside the backend using the Cloud Run terraform module:

```bash
cd ../terraform/modules/cloud_run
terraform plan
terraform apply
```

See [docs/AI_RESEARCH_ASSISTANT.md](../docs/AI_RESEARCH_ASSISTANT.md) for complete deployment guide.

## Development

### Adding New Components

```bash
# Create new component
touch components/YourComponent.tsx
```

```typescript
// components/YourComponent.tsx
import React from 'react';

interface YourComponentProps {
  title: string;
}

export default function YourComponent({ title }: YourComponentProps) {
  return <div className="component">{title}</div>;
}
```

### Code Style

- Use TypeScript for all new code
- Follow Next.js app directory conventions
- Use Tailwind CSS for styling
- Run `npm run lint` before committing

## Features

- 🎨 Modern, responsive UI with Tailwind CSS
- ⚡ Server-side rendering with Next.js
- 🔒 Type-safe development with TypeScript
- 📱 Mobile-friendly design
- 🌐 Markdown support for rich content
- 🚀 Optimized for production deployment

## Integration with Backend

The frontend communicates with the backend API (see [backend/](../backend/)) via REST endpoints:

- `POST /api/chat` - Send chat messages
- `GET /api/history` - Retrieve conversation history
- `GET /api/health` - Health check endpoint

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
lsof -ti:3000

# Kill the process
kill -9 $(lsof -ti:3000)

# Or use a different port
PORT=3001 npm run dev
```

### Build Errors

```bash
# Clear Next.js cache
rm -rf .next

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Rebuild
npm run build
```

## Contributing

Please see [../CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

## License

Same as parent project license.
