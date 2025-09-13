// Commitlint 配置文件
// 用于验证Git提交信息是否符合规范

module.exports = {
  extends: ['@commitlint/config-conventional'],

  // 自定义规则
  rules: {
    // 类型必须是以下之一
    'type-enum': [
      2,
      'always',
      [
        'feat',     // 新功能
        'fix',      // 修复bug
        'docs',     // 文档更新
        'style',    // 代码格式化
        'refactor', // 代码重构
        'test',     // 测试相关
        'chore',    // 构建/工具相关
        'perf',     // 性能优化
        'ci',       // CI/CD相关
        'build',    // 构建系统
        'revert'    // 回滚提交
      ]
    ],

    // 作用域必须是以下之一（可选）
    'scope-enum': [
      2,
      'always',
      [
        'api',        // API接口相关
        'auth',       // 认证授权
        'db',         // 数据库相关
        'docker',     // Docker相关
        'config',     // 配置文件
        'middleware', // 中间件
        'model',      // 数据模型
        'service',    // 业务逻辑
        'handler',    // 请求处理
        'test',       // 测试相关
        'ci',         // CI/CD
        'docs',       // 文档
        'user',       // 用户相关
        'post',       // 博客相关
        'server',     // 服务器相关
        'client',     // 客户端相关
        'utils',      // 工具函数
        'deps'        // 依赖相关
      ]
    ],

    // 主题（描述）不能为空
    'subject-empty': [2, 'never'],

    // 主题不能以句号结尾
    'subject-full-stop': [2, 'never', '.'],

    // 主题格式：小写开头
    'subject-case': [2, 'always', 'lower-case'],

    // 主题最大长度
    'subject-max-length': [2, 'always', 50],

    // 类型不能为空
    'type-empty': [2, 'never'],

    // 类型格式：小写
    'type-case': [2, 'always', 'lower-case'],

    // 作用域格式：小写
    'scope-case': [2, 'always', 'lower-case'],

    // 正文最大行长度
    'body-max-line-length': [2, 'always', 72],

    // 页脚最大行长度
    'footer-max-line-length': [2, 'always', 72],

    // 头部最大长度
    'header-max-length': [2, 'always', 72]
  },

  // 忽略规则（针对特定情况）
  ignores: [
    // 忽略merge提交
    (commit) => commit.includes('Merge'),
    // 忽略revert提交的特殊格式
    (commit) => commit.includes('Revert')
  ],

  // 默认忽略的提交类型
  defaultIgnores: true,

  // 帮助信息
  helpUrl: 'https://github.com/conventional-changelog/commitlint/#what-is-commitlint',

  // 自定义提示信息
  prompt: {
    messages: {
      type: '选择你要提交的类型:',
      scope: '选择一个scope (可选):',
      customScope: '请输入自定义的scope:',
      subject: '填写简短精炼的变更描述:',
      body: '填写更加详细的变更描述 (可选)。使用 "|" 换行:',
      breaking: '列举非兼容性重大的变更 (可选):',
      footer: '列举出所有变更的 ISSUES CLOSED (可选)。 例如: #31, #34:',
      confirmCommit: '确认提交?'
    },
    types: [
      { value: 'feat', name: 'feat:     新功能' },
      { value: 'fix', name: 'fix:      修复' },
      { value: 'docs', name: 'docs:     文档变更' },
      { value: 'style', name: 'style:    代码格式(不影响代码运行的变动)' },
      { value: 'refactor', name: 'refactor: 重构(既不是增加feature，也不是修复bug)' },
      { value: 'perf', name: 'perf:     性能优化' },
      { value: 'test', name: 'test:     增加测试' },
      { value: 'chore', name: 'chore:    构建过程或辅助工具的变动' },
      { value: 'revert', name: 'revert:   回退' },
      { value: 'build', name: 'build:    打包' },
      { value: 'ci', name: 'ci:       CI/CD相关' }
    ],
    useEmoji: false,
    emojiAlign: 'center',
    allowCustomScopes: true,
    allowEmptyScopes: true,
    customScopesAlign: 'bottom',
    customScopesAlias: 'custom',
    emptyScopesAlias: 'empty',
    upperCaseSubject: false,
    markBreakingChangeMode: false,
    allowBreakingChanges: ['feat', 'fix'],
    breaklineNumber: 100,
    breaklineChar: '|',
    skipQuestions: [],
    issuePrefixes: [{ value: 'closed', name: 'closed:   ISSUES has been processed' }],
    customIssuePrefixAlign: 'top',
    emptyIssuePrefixAlias: 'skip',
    customIssuePrefixAlias: 'custom',
    allowCustomIssuePrefix: true,
    allowEmptyIssuePrefix: true,
    confirmColorize: true,
    maxHeaderLength: Infinity,
    maxSubjectLength: Infinity,
    minSubjectLength: 0,
    scopeOverrides: undefined,
    defaultBody: '',
    defaultIssues: '',
    defaultScope: '',
    defaultSubject: ''
  }
};