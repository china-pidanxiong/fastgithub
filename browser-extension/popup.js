const SERVER_URL = 'http://localhost:17890';
let pollingInterval = null;

const elements = {
  serverStatus: document.getElementById('serverStatus'),
  updateStatus: document.getElementById('updateStatus'),
  lastRunItem: document.getElementById('lastRunItem'),
  lastRun: document.getElementById('lastRun'),
  refreshBtn: document.getElementById('refreshBtn'),
  logSection: document.getElementById('logSection'),
  logContent: document.getElementById('logContent'),
  toggleLogBtn: document.getElementById('toggleLogBtn'),
  errorSection: document.getElementById('errorSection'),
  helpSection: document.getElementById('helpSection'),
  helpBtn: document.getElementById('helpBtn'),
};

/**
 * 向本地服务器发送请求
 * @param {string} path - API 路径
 * @param {object} options - fetch 选项
 * @returns {Promise<object>} 响应数据
 */
async function apiRequest(path, options = {}) {
  try {
    const response = await fetch(`${SERVER_URL}${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });
    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      throw new Error(data.message || `HTTP ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    throw error;
  }
}

/**
 * 检查服务健康状态
 */
async function checkHealth() {
  try {
    const data = await apiRequest('/health');
    if (data.status === 'ok') {
      showServerConnected();
      return true;
    }
  } catch (error) {
    // 忽略错误，由调用方处理
  }
  showServerDisconnected();
  return false;
}

/**
 * 获取更新状态
 */
async function getStatus() {
  try {
    const data = await apiRequest('/status');
    updateStatusUI(data);
    return data;
  } catch (error) {
    showServerDisconnected();
    return null;
  }
}

/**
 * 获取最后一次更新结果（包含日志）
 */
async function getLastResult() {
  try {
    const data = await apiRequest('/last-result');
    updateStatusUI(data);
    if (data.outputLog && data.outputLog.length > 0) {
      showLog(data.outputLog);
    }
    return data;
  } catch (error) {
    return null;
  }
}

/**
 * 触发更新
 */
async function triggerUpdate() {
  if (elements.refreshBtn.disabled) return;

  setButtonLoading(true);
  hideError();

  try {
    const data = await apiRequest('/update', { method: 'POST' });
    if (data.success) {
      startPolling();
    } else {
      throw new Error(data.message || '更新启动失败');
    }
  } catch (error) {
    showError(error.message || '无法连接到本地服务');
    setButtonLoading(false);
  }
}

/**
 * 轮询更新状态
 */
function startPolling() {
  if (pollingInterval) {
    clearInterval(pollingInterval);
  }

  let pollCount = 0;
  const maxPolls = 60;

  pollingInterval = setInterval(async () => {
    pollCount++;
    const status = await getStatus();

    if (!status) {
      clearInterval(pollingInterval);
      pollingInterval = null;
      setButtonLoading(false);
      return;
    }

    if (!status.isRunning) {
      clearInterval(pollingInterval);
      pollingInterval = null;
      setButtonLoading(false);
      getLastResult();
    }

    if (pollCount >= maxPolls) {
      clearInterval(pollingInterval);
      pollingInterval = null;
      setButtonLoading(false);
    }
  }, 2000);
}

/**
 * 更新状态 UI
 * @param {object} data - 状态数据
 */
function updateStatusUI(data) {
  if (data.isRunning) {
    elements.updateStatus.textContent = '更新中...';
    elements.updateStatus.className = 'status-value status-running';
  } else if (data.lastResult === true) {
    elements.updateStatus.textContent = '更新成功';
    elements.updateStatus.className = 'status-value status-success';
  } else if (data.lastResult === false) {
    elements.updateStatus.textContent = '更新失败';
    elements.updateStatus.className = 'status-value status-error';
  } else {
    elements.updateStatus.textContent = '等待中';
    elements.updateStatus.className = 'status-value status-idle';
  }

  if (data.lastRun) {
    elements.lastRunItem.style.display = 'flex';
    const date = new Date(data.lastRun);
    elements.lastRun.textContent = formatDateTime(date);
  }
}

/**
 * 显示服务已连接
 */
function showServerConnected() {
  elements.serverStatus.textContent = '运行中';
  elements.serverStatus.className = 'status-value status-success';
  elements.refreshBtn.disabled = false;
  elements.errorSection.style.display = 'none';
}

/**
 * 显示服务未连接
 */
function showServerDisconnected() {
  elements.serverStatus.textContent = '未连接';
  elements.serverStatus.className = 'status-value status-error';
  elements.refreshBtn.disabled = true;
  showError('无法连接到本地服务');
}

/**
 * 显示错误
 * @param {string} message - 错误消息
 */
function showError(message) {
  elements.errorSection.style.display = 'flex';
}

/**
 * 隐藏错误
 */
function hideError() {
  elements.errorSection.style.display = 'none';
}

/**
 * 设置按钮加载状态
 * @param {boolean} loading - 是否加载中
 */
function setButtonLoading(loading) {
  const btn = elements.refreshBtn;
  const btnText = btn.querySelector('.btn-text');

  if (loading) {
    btn.disabled = true;
    btn.classList.add('loading');
    btnText.textContent = '刷新中...';
  } else {
    btn.disabled = false;
    btn.classList.remove('loading');
    btnText.textContent = '立即刷新';
  }
}

/**
 * 显示日志
 * @param {string[]} logs - 日志行数组
 */
function showLog(logs) {
  if (!logs || logs.length === 0) {
    elements.logSection.style.display = 'none';
    return;
  }

  elements.logSection.style.display = 'block';
  elements.logContent.innerHTML = logs.map(line =>
    `<div>${escapeHtml(line)}</div>`
  ).join('');
}

/**
 * 切换日志显示
 */
function toggleLog() {
  const isHidden = elements.logContent.style.display === 'none';
  elements.logContent.style.display = isHidden ? 'block' : 'none';
  elements.toggleLogBtn.textContent = isHidden ? '收起' : '展开';
}

/**
 * 切换帮助显示
 */
function toggleHelp() {
  const isHidden = elements.helpSection.style.display === 'none';
  elements.helpSection.style.display = isHidden ? 'block' : 'none';
}

/**
 * 格式化日期时间
 * @param {Date} date - 日期对象
 * @returns {string} 格式化后的字符串
 */
function formatDateTime(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return '-';
  const now = new Date();
  const diff = now - date;

  if (diff < 60000) {
    return '刚刚';
  }
  if (diff < 3600000) {
    return `${Math.floor(diff / 60000)} 分钟前`;
  }
  if (diff < 86400000) {
    return `${Math.floor(diff / 3600000)} 小时前`;
  }

  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * HTML 转义
 * @param {string} str - 输入字符串
 * @returns {string} 转义后的字符串
 */
function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// 事件绑定
elements.refreshBtn.addEventListener('click', triggerUpdate);
elements.toggleLogBtn.addEventListener('click', toggleLog);
elements.helpBtn.addEventListener('click', toggleHelp);

// 初始化
document.addEventListener('DOMContentLoaded', async () => {
  const healthy = await checkHealth();
  if (healthy) {
    await getLastResult();
  }
});
