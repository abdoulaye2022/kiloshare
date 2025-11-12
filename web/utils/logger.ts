/**
 * Conditional logger that only logs in development
 */

const isDev = process.env.NODE_ENV === 'development'

export const logger = {
  log: (...args: any[]) => {
    if (isDev) console.log(...args)
  },

  error: (...args: any[]) => {
    if (isDev) console.error(...args)
  },

  warn: (...args: any[]) => {
    if (isDev) console.warn(...args)
  },

  info: (...args: any[]) => {
    if (isDev) console.info(...args)
  },

  debug: (...args: any[]) => {
    if (isDev) console.debug(...args)
  },
}

// Always log errors in production
export const logError = (error: Error, context?: any) => {
  console.error('[ERROR]', error.message, context)
  // TODO: Send to error tracking service (Sentry, etc.)
}
