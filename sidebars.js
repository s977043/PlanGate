/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
module.exports = {
  docs: [
    'index',
    {
      type: 'category',
      label: 'ガイド',
      items: [
        'guides/product-demo-script',
        {
          type: 'category',
          label: 'ガバナンス',
          items: ['guides/governance/documentation-management'],
        },
      ],
    },
    {
      type: 'category',
      label: 'リファレンス',
      items: ['reference/product-faq'],
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
            'explanation/product/pm-po-elevator-pitch',
            'explanation/product/before-after',
            'explanation/product/positioning',
            'explanation/product/value-proposition-canvas',
          ],
        },
      ],
    },
  ],
};
