<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getUserList, createUser, updateUser, deleteUser, addUserDuration, type User } from '#/api/admin/users';

const loading = ref(false);
const list = ref<User[]>([]);
const total = ref(0);
const keyword = ref('');
const page = reactive({ current: 1, size: 20 });
let refreshTimer: number | undefined;

const dialogVisible = ref(false);
const isEdit = ref(false);
const editId = ref(0);
const form = reactive({
  username: '',
  password: '',
  phone: '',
  status: 1,
  free_used_seconds: 0,
  free_limit_seconds: 2700,
  remaining_days: 0,
  remaining_hours: 0,
  remaining_minutes: 0,
  remaining_traffic_gb: 0,
  unlimited_traffic: false,
});

const durationDialogVisible = ref(false);
const durationUserId = ref(0);
const durationAmount = ref(1);
const durationUnit = ref<'minute' | 'hour' | 'day' | 'month' | 'year'>('day');
const durationTrafficGB = ref(0); // 追加流量 GB，0 表示不追加

const durationUnitOptions = [
  { label: '分钟', value: 'minute' },
  { label: '小时', value: 'hour' },
  { label: '天', value: 'day' },
  { label: '月', value: 'month' },
  { label: '年', value: 'year' },
];

const durationMaxMap: Record<string, number> = {
  minute: 525600, // 1年的分钟数
  hour: 8760,
  day: 365,
  month: 12,
  year: 1,
};

function toSeconds(amount: number, unit: string): number {
  switch (unit) {
    case 'minute': return amount * 60;
    case 'hour': return amount * 3600;
    case 'day': return amount * 86400;
    case 'month': return amount * 30 * 86400;
    case 'year': return amount * 365 * 86400;
    default: return amount * 86400;
  }
}

async function load() {
  loading.value = true;
  try {
    const res = await getUserList({ page: page.current, size: page.size, keyword: keyword.value });
    list.value = res?.list ?? [];
    total.value = res?.total ?? 0;
  } finally { loading.value = false; }
}

function handleSearch() { page.current = 1; load(); }

const editSnapshot = ref({
  remainingSeconds: 0,
  trafficRemainingBytes: 0 as number | null,
});

function calcRemainingSeconds(expiredAt: string | null) {
  if (!expiredAt) return -1;
  return Math.max(0, Math.floor((new Date(expiredAt).getTime() - Date.now()) / 1000));
}

function calcRemainingTrafficBytes(usedBytes: number, limitBytes: number | null) {
  if (limitBytes === null || limitBytes === undefined) return null;
  return Math.max(0, limitBytes - usedBytes);
}

function calcRemainingParts(expiredAt: string | null) {
  if (!expiredAt) {
    return { days: 0, hours: 0, minutes: 0 };
  }
  const diff = Math.max(0, Math.floor((new Date(expiredAt).getTime() - Date.now()) / 1000));
  return {
    days: Math.floor(diff / 86400),
    hours: Math.floor((diff % 86400) / 3600),
    minutes: Math.floor((diff % 3600) / 60),
  };
}

function calcRemainingTrafficGB(usedBytes: number, limitBytes: number | null) {
  if (limitBytes === null || limitBytes === undefined) {
    return { unlimited: true, gb: 0 };
  }
  const left = Math.max(0, limitBytes - usedBytes);
  return {
    unlimited: false,
    gb: Number((left / 1024 / 1024 / 1024).toFixed(2)),
  };
}

function openCreate() {
  isEdit.value = false;
  Object.assign(form, {
    username: '',
    password: '',
    phone: '',
    status: 1,
    free_used_seconds: 0,
    free_limit_seconds: 2700,
    remaining_days: 0,
    remaining_hours: 0,
    remaining_minutes: 0,
    remaining_traffic_gb: 0,
    unlimited_traffic: false,
  });
  dialogVisible.value = true;
}

function openEdit(row: User) {
  isEdit.value = true;
  editId.value = row.id;
  const remaining = calcRemainingParts(row.plan_expired_at);
  const traffic = calcRemainingTrafficGB(row.traffic_used_bytes, row.traffic_limit_bytes);
  editSnapshot.value = {
    remainingSeconds: calcRemainingSeconds(row.plan_expired_at),
    trafficRemainingBytes: calcRemainingTrafficBytes(row.traffic_used_bytes, row.traffic_limit_bytes),
  };
  Object.assign(form, {
    username: row.username,
    password: '',
    phone: row.phone || '',
    status: row.status,
    free_used_seconds: row.free_used_seconds,
    free_limit_seconds: row.free_limit_seconds,
    remaining_days: remaining.days,
    remaining_hours: remaining.hours,
    remaining_minutes: remaining.minutes,
    remaining_traffic_gb: traffic.gb,
    unlimited_traffic: traffic.unlimited,
  });
  dialogVisible.value = true;
}

async function handleSubmit() {
  if (!isEdit.value) {
    if (!form.username || !form.password) { ElMessage.warning('用户名和密码必填'); return; }
    await createUser({ username: form.username, password: form.password, phone: form.phone, free_limit_seconds: form.free_limit_seconds });
    ElMessage.success('创建成功');
  } else {
    const remainingSeconds =
      form.remaining_days * 86400 +
      form.remaining_hours * 3600 +
      form.remaining_minutes * 60;
    const trafficRemainingBytes = form.unlimited_traffic
      ? -1
      : Math.round(form.remaining_traffic_gb * 1024 * 1024 * 1024);
    const snapshotTraffic = editSnapshot.value.trafficRemainingBytes === null
      ? -1
      : editSnapshot.value.trafficRemainingBytes;

    const data: any = {
      status: form.status,
      phone: form.phone,
      free_used_seconds: form.free_used_seconds,
      free_limit_seconds: form.free_limit_seconds,
    };

    const shouldUpdateRemaining =
      !(editSnapshot.value.remainingSeconds === -1 && remainingSeconds === 0) &&
      remainingSeconds !== editSnapshot.value.remainingSeconds;
    if (shouldUpdateRemaining) {
      data.remaining_seconds = remainingSeconds;
    }
    if (trafficRemainingBytes !== snapshotTraffic) {
      data.traffic_remaining_bytes = trafficRemainingBytes;
    }
    if (form.password) data.password = form.password;
    await updateUser(editId.value, data);
    ElMessage.success('更新成功');
  }
  dialogVisible.value = false;
  load();
}

async function handleToggle(row: User) {
  await updateUser(row.id, { status: row.status === 1 ? 0 : 1 });
  ElMessage.success(row.status === 1 ? '已禁用' : '已启用');
  load();
}

async function handleDelete(row: User) {
  await ElMessageBox.confirm(
    `确定永久删除用户“${row.username}”？删除后该用户所有设备会立即退出登录，此操作不可恢复。`,
    '删除用户',
    {
      type: 'warning',
      confirmButtonText: '确认删除',
      cancelButtonText: '取消',
      confirmButtonClass: 'el-button--danger',
    },
  );
  await deleteUser(row.id);
  ElMessage.success('删除成功');
  load();
}

function openAddDuration(row: User) {
  durationUserId.value = row.id;
  durationAmount.value = 1;
  durationUnit.value = 'minute';
  durationTrafficGB.value = 0;
  durationDialogVisible.value = true;
}

async function handleAddDuration() {
  if (durationAmount.value < 1) {
    ElMessage.warning('追加数量必须大于0');
    return;
  }
  const seconds = toSeconds(durationAmount.value, durationUnit.value);
  const trafficBytes = durationTrafficGB.value > 0 ? durationTrafficGB.value * 1024 * 1024 * 1024 : 0;
  await addUserDuration(durationUserId.value, seconds, trafficBytes);
  ElMessage.success('追加成功');
  durationDialogVisible.value = false;
  load();
}

const fmtSec = (s: number) => `${Math.floor(s / 60)} 分钟`;
const fmtTime = (t: string) => {
  if (!t) return '-';
  const d = new Date(t);
  if (Number.isNaN(d.getTime())) return t;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
};

// 剩余时长
function fmtRemaining(expiredAt: string | null): string {
  if (!expiredAt) return '未开通';
  const diff = new Date(expiredAt).getTime() - Date.now();
  if (diff <= 0) return '已到期';
  const days = Math.floor(diff / 86400000);
  const hours = Math.floor((diff % 86400000) / 3600000);
  if (days > 0) return `${days}天${hours > 0 ? ` ${hours}小时` : ''}`;
  const mins = Math.floor((diff % 3600000) / 60000);
  return hours > 0 ? `${hours}小时${mins > 0 ? ` ${mins}分` : ''}` : `${mins}分钟`;
}

// 剩余流量
function fmtTraffic(usedBytes: number, limitBytes: number | null): string {
  if (limitBytes === null || limitBytes === undefined) return '不限流量';
  const left = limitBytes - usedBytes;
  if (left <= 0) return '0 GB';
  const gb = left / 1024 / 1024 / 1024;
  return gb >= 1 ? `${gb.toFixed(2)} GB` : `${(left / 1024 / 1024).toFixed(1)} MB`;
}

onMounted(() => {
  load();
  refreshTimer = window.setInterval(load, 30_000);
});

onUnmounted(() => {
  if (refreshTimer !== undefined) window.clearInterval(refreshTimer);
});
</script>

<template>
  <div class="p-4">
    <el-card>
      <div class="mb-4 flex items-center justify-between">
        <el-input v-model="keyword" placeholder="搜索用户名/手机号/设备ID" style="width:280px" clearable @keyup.enter="handleSearch">
          <template #append><el-button @click="handleSearch">搜索</el-button></template>
        </el-input>
        <el-button type="primary" @click="openCreate">新增用户</el-button>
      </div>

      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="username" label="用户名" width="120" />
        <!-- <el-table-column prop="phone" label="手机号" width="130" /> -->
        <el-table-column prop="device_id" label="设备ID(内部)" width="110" show-overflow-tooltip />
        <el-table-column label="展示ID" width="90">
          <template #default="{ row }">
            <span style="font-weight:600;letter-spacing:1px">{{ row.display_id || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="套餐到期" width="155">
          <template #default="{ row }">{{ row.plan_expired_at ? fmtTime(row.plan_expired_at) : '未开通' }}</template>
        </el-table-column>
        <el-table-column label="剩余时长" width="130">
          <template #default="{ row }">
            <el-tag :type="!row.plan_expired_at ? 'info' : new Date(row.plan_expired_at) > new Date() ? 'success' : 'danger'" size="small">
              {{ fmtRemaining(row.plan_expired_at) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="剩余流量" width="120">
          <template #default="{ row }">
            <span :style="{ color: row.traffic_limit_bytes !== null && (row.traffic_limit_bytes - row.traffic_used_bytes) <= 0 ? '#f56c6c' : '' }">
              {{ fmtTraffic(row.traffic_used_bytes, row.traffic_limit_bytes) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="免费时长" width="150">
          <template #default="{ row }">{{ fmtSec(row.free_used_seconds) }} / {{ fmtSec(row.free_limit_seconds) }}</template>
        </el-table-column>
        <el-table-column label="线路ID" width="90">
          <template #default="{ row }">{{ row.current_line_id ?? '未分配' }}</template>
        </el-table-column>
        <el-table-column label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'">{{ row.status === 1 ? '正常' : '禁用' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="在线状态" width="110" align="center">
          <template #default="{ row }">
            <el-tag :type="row.is_online ? 'success' : 'info'" effect="dark">
              {{ row.is_online ? `在线 ${row.online_devices} 台` : '离线' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最后在线" width="170">
          <template #default="{ row }">{{ row.last_active_at ? fmtTime(row.last_active_at) : '-' }}</template>
        </el-table-column>
        <el-table-column prop="created_at" label="注册时间" width="170">
          <template #default="{ row }">{{ fmtTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column prop="last_ip" label="最后IP" width="140" />
        <el-table-column label="IP 详情" min-width="220">
          <template #default="{ row }">
            <div>{{ row.last_ip_detail?.location || '未知' }}</div>
            <div class="text-xs text-gray-500">
              {{ row.last_ip_detail?.type || '-' }}
              <span v-if="row.last_ip_detail?.is_private"> / 内网</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="350" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="openEdit(row)">编辑</el-button>
            <el-button size="small" type="primary" @click="openAddDuration(row)">追加时长</el-button>
            <el-button size="small" :type="row.status === 1 ? 'warning' : 'success'" @click="handleToggle(row)">
              {{ row.status === 1 ? '禁用' : '启用' }}
            </el-button>
            <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="mt-4 flex justify-end">
        <el-pagination
          v-model:current-page="page.current"
          v-model:page-size="page.size"
          :total="total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next"
          @change="load"
        />
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑用户' : '新增用户'" width="560px">
      <el-form :model="form" label-width="140px">
        <el-form-item label="用户名" required>
          <el-input v-model="form.username" :disabled="isEdit" />
        </el-form-item>
        <el-form-item :label="isEdit ? '新密码（留空不改）' : '密码'" :required="!isEdit">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" />
        </el-form-item>
        <el-form-item v-if="isEdit" label="状态">
          <el-radio-group v-model="form.status">
            <el-radio :value="1">正常</el-radio>
            <el-radio :value="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="isEdit" label="剩余时长">
          <div style="display:flex;gap:8px;width:100%">
            <el-input-number v-model="form.remaining_days" :min="0" :max="3650" style="flex:1" />
            <span>天</span>
            <el-input-number v-model="form.remaining_hours" :min="0" :max="23" style="flex:1" />
            <span>时</span>
            <el-input-number v-model="form.remaining_minutes" :min="0" :max="59" style="flex:1" />
            <span>分</span>
          </div>
        </el-form-item>
        <el-form-item v-if="isEdit" label="剩余流量">
          <div style="display:flex;align-items:center;gap:12px;width:100%">
            <el-input-number
              v-model="form.remaining_traffic_gb"
              :min="0"
              :max="10240"
              :disabled="form.unlimited_traffic"
              style="flex:1"
            />
            <span>GB</span>
            <el-checkbox v-model="form.unlimited_traffic">不限流量</el-checkbox>
          </div>
        </el-form-item>
        <el-form-item v-if="isEdit" label="已用免费时长(秒)">
          <el-input-number v-model="form.free_used_seconds" :min="0" style="width:100%" />
        </el-form-item>
        <el-form-item label="免费时长上限(秒)">
          <el-input-number v-model="form.free_limit_seconds" :min="0" style="width:100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="durationDialogVisible" title="追加时长" width="420px">
      <el-form label-width="100px">
        <el-form-item label="追加时长" required>
          <div style="display:flex;gap:8px;width:100%">
            <el-input-number
              v-model="durationAmount"
              :min="1"
              :max="durationMaxMap[durationUnit]"
              style="flex:1"
            />
            <el-select v-model="durationUnit" style="width:90px">
              <el-option
                v-for="opt in durationUnitOptions"
                :key="opt.value"
                :label="opt.label"
                :value="opt.value"
              />
            </el-select>
          </div>
        </el-form-item>
        <el-form-item label="追加流量">
          <div style="display:flex;align-items:center;gap:8px">
            <el-input-number v-model="durationTrafficGB" :min="0" :max="10240" style="flex:1" />
            <span style="color:#666">GB（0 = 不追加）</span>
          </div>
        </el-form-item>
        <el-form-item label="换算">
          <span style="color:#666;font-size:13px">
            ≈ {{ (toSeconds(durationAmount, durationUnit) / 86400).toFixed(2) }} 天
          </span>
        </el-form-item>
        <el-alert type="info" :closable="false" show-icon>
          <template #default>
            <div>如果用户当前有剩余时长，将在原有基础上追加</div>
            <div>如果已过期或未开通，将从当前时间开始计算</div>
          </template>
        </el-alert>
      </el-form>
      <template #footer>
        <el-button @click="durationDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleAddDuration">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>
