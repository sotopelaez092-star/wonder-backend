module.exports = {
  apps: [{
    name: 'wonder-backend',
    script: 'src/server.js',
    cwd: __dirname,
    env: { NODE_ENV: 'production' },
    max_memory_restart: '300M',
    out_file: '../data/pm2.out.log',
    error_file: '../data/pm2.err.log',
    merge_logs: true,
    autorestart: true,
    watch: false,
  }],
};
