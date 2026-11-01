import React from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/montserrat'
import '../index.css'
import './panel.css'
import PanelApp from './PanelApp.jsx'

createRoot(document.getElementById('root')).render(<PanelApp />)
