import { ReactNode } from 'react';
import Navbar from './Navbar';
import BackgroundEffects from './BackgroundEffects';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  return (
    <div className="min-h-screen bg-dark-900 relative">
      <BackgroundEffects />
      <Navbar />
      <main className="relative z-10 pt-20 pb-12 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
        {children}
      </main>
    </div>
  );
}
