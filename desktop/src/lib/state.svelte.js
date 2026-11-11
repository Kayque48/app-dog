// Estado global simples: usuário logado, página atual e avisos.
import { api, setToken } from './api.js';

export const app = $state({
  me: null,
  page: 'feed', // feed | discover | matches | places | dogs | dog | owner | profile | admin
  param: null, // id do cão ou do dono nas páginas de detalhe
  toast: null,
  counts: { requests: 0 }, // pedidos de encontro esperando resposta (badge no menu)
});

export function go(page, param = null) {
  app.page = page;
  app.param = param;
}

let toastTimer;
export function toast(message) {
  app.toast = message;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (app.toast = null), 4000);
}

/** Mostra o erro; se a sessão caiu ou a conta foi bloqueada, volta ao login. */
export function showError(e) {
  if (e.status === 401 || e.message?.startsWith('Conta bloqueada')) {
    setToken(null);
    app.me = null;
  }
  toast(e.message);
}

export async function loadMe() {
  try {
    app.me = await api('GET', '/me');
  } catch (e) {
    showError(e);
  }
}

/** Envia a posição do computador (se o sistema permitir) para a API. */
export function updateLocation() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) return resolve(false);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        await api('PUT', '/me/location', { lat: pos.coords.latitude, lng: pos.coords.longitude }).catch(() => {});
        resolve(true);
      },
      () => resolve(false),
      { timeout: 8000 },
    );
  });
}

/** Atualiza os contadores do menu (pedidos de encontro recebidos). */
export async function loadCounts() {
  try {
    const items = await api('GET', '/matches');
    app.counts.requests = items.filter((m) => m.status === 'pending' && m.direction === 'incoming').length;
  } catch {
    /* sem conexão: mantém o último valor */
  }
}
