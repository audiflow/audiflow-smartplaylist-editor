import type { ReactNode } from 'react';
import type { ApiClient } from './client.ts';
import { ApiClientContext } from './client-context.ts';

export function ApiClientProvider({
  client,
  children,
}: {
  client: ApiClient;
  children: ReactNode;
}) {
  return (
    <ApiClientContext.Provider value={client}>
      {children}
    </ApiClientContext.Provider>
  );
}
