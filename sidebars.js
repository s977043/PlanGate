/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
module.exports = {
  docs: [
    'index',
    {
      type: 'category',
      label: 'ガイド',
      items: [
        'guides/getting-started',
        'guides/product-demo-script',
        'guides/codex-guarded-execution',
        {
          type: 'category',
          label: 'ガバナンス',
          items: [
            'guides/governance/documentation-management',
            'guides/governance/oss-governance',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'リファレンス',
      items: ['reference/product-faq', 'reference/glossary'],
    },
    {
      type: 'category',
      label: '解説',
      items: [
        {
          type: 'category',
          label: 'プロダクト',
          items: [
            'explanation/product/overview',
            'explanation/product/why-plangate',
            'explanation/product/philosophy',
            'explanation/product/when-not-to-use',
            'explanation/product/pm-po-elevator-pitch',
            'explanation/product/before-after',
            'explanation/product/positioning',
            'explanation/product/value-proposition-canvas',
            'explanation/product/plan-creation-process',
          ],
        },
      ],
    },
  ],
};
