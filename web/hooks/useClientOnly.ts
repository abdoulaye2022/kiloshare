'use client';

import { useState, useEffect } from 'react';

/**
 * Hook to ensure components only render after hydration
 * Prevents hydration mismatch errors
 */
export const useClientOnly = (delay: number = 0) => {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      setMounted(true);
    }, delay);

    return () => clearTimeout(timer);
  }, [delay]);

  return mounted;
};