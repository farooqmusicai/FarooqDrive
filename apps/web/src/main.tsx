import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthPage } from './pages/AuthPage';
import { DashboardPage } from './pages/DashboardPage';
import { SettingsPage } from './pages/SettingsPage';
import './styles.css';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><BrowserRouter><Routes><Route path="/" element={<AuthPage/>}/><Route path="/dashboard" element={<DashboardPage/>}/><Route path="/settings" element={<SettingsPage/>}/></Routes></BrowserRouter></React.StrictMode>);
