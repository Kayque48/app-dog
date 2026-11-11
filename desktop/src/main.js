import { mount } from 'svelte';
// Fonte Roboto e ícones Material Symbols ficam empacotados no app (funciona offline).
import '@fontsource/roboto/400.css';
import '@fontsource/roboto/500.css';
import 'material-symbols/rounded.css';
import '@fontsource-variable/bricolage-grotesque';
import './shapes.css';
import './app.css';
import App from './App.svelte';

export default mount(App, { target: document.getElementById('app') });
