import React, { useState, useRef } from 'react';
import { Download } from 'lucide-react';

const IOSIconGenerator = () => {
  const [generating, setGenerating] = useState(false);
  const canvasRef = useRef(null);

  const iconSizes = [
    { name: 'iPhone Notification', size: 40, scale: [2, 3] },
    { name: 'iPhone Settings', size: 58, scale: [2, 3] },
    { name: 'iPhone Spotlight', size: 80, scale: [2, 3] },
    { name: 'iPhone App', size: 120, scale: [2, 3] },
    { name: 'iPad Notifications', size: 40, scale: [1, 2] },
    { name: 'iPad Settings', size: 58, scale: [1, 2] },
    { name: 'iPad Spotlight', size: 80, scale: [1, 2] },
    { name: 'iPad App', size: 152, scale: [1, 2] },
    { name: 'iPad Pro App', size: 167, scale: [1] },
    { name: 'App Store', size: 1024, scale: [1] },
  ];

  const svgContent = `<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#a8e6cf;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#56c596;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="leafGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ffffff;stop-opacity:0.9" />
      <stop offset="100%" style="stop-color:#ffffff;stop-opacity:0.7" />
    </linearGradient>
  </defs>
  <rect width="200" height="200" rx="45" fill="url(#bgGradient)"/>
  <g transform="translate(100, 100)">
    <circle cx="0" cy="0" r="18" fill="#ffffff" opacity="0.95"/>
    <g opacity="0.9">
      <ellipse cx="0" cy="-35" rx="20" ry="32" fill="url(#leafGradient)"/>
      <ellipse cx="30" cy="-17" rx="20" ry="32" fill="url(#leafGradient)" transform="rotate(72 30 -17)"/>
      <ellipse cx="19" cy="28" rx="20" ry="32" fill="url(#leafGradient)" transform="rotate(144 19 28)"/>
      <ellipse cx="-19" cy="28" rx="20" ry="32" fill="url(#leafGradient)" transform="rotate(216 -19 28)"/>
      <ellipse cx="-30" cy="-17" rx="20" ry="32" fill="url(#leafGradient)" transform="rotate(288 -30 -17)"/>
    </g>
    <g opacity="0.8">
      <ellipse cx="0" cy="-22" rx="12" ry="20" fill="#ffffff"/>
      <ellipse cx="19" cy="-11" rx="12" ry="20" fill="#ffffff" transform="rotate(72 19 -11)"/>
      <ellipse cx="12" cy="18" rx="12" ry="20" fill="#ffffff" transform="rotate(144 12 18)"/>
      <ellipse cx="-12" cy="18" rx="12" ry="20" fill="#ffffff" transform="rotate(216 -12 18)"/>
      <ellipse cx="-19" cy="-11" rx="12" ry="20" fill="#ffffff" transform="rotate(288 -19 -11)"/>
    </g>
  </g>
</svg>`;

  const generateIcon = async (size) => {
    return new Promise((resolve, reject) => {
      const canvas = canvasRef.current;
      const ctx = canvas.getContext('2d');
      canvas.width = size;
      canvas.height = size;

      const img = new Image();
      const blob = new Blob([svgContent], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);

      img.onload = () => {
        ctx.drawImage(img, 0, 0, size, size);
        canvas.toBlob((blob) => {
          URL.revokeObjectURL(url);
          resolve(blob);
        }, 'image/png');
      };

      img.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error('Failed to load image'));
      };

      img.src = url;
    });
  };

  const downloadIcon = async (size, scaleName) => {
    setGenerating(true);
    try {
      const blob = await generateIcon(size);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `icon-${size}x${size}${scaleName}.png`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Error generating icon:', error);
      alert('Failed to generate icon. Please try again.');
    }
    setGenerating(false);
  };

  const downloadAll = async () => {
    setGenerating(true);
    for (const icon of iconSizes) {
      for (const scale of icon.scale) {
        const actualSize = icon.size * (scale === 1 ? 1 : scale === 2 ? 1 : scale === 3 ? 1.5 : 1);
        const finalSize = scale === 1 ? icon.size : icon.size * scale / 2;
        await downloadIcon(finalSize, scale > 1 ? `@${scale}x` : '');
        await new Promise(resolve => setTimeout(resolve, 300));
      }
    }
    setGenerating(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-teal-50 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">iOS App Icon Generator</h1>
          <p className="text-gray-600 mb-8">Download your wellness app icon in all required iOS sizes</p>

          <div className="flex justify-center mb-8">
            <div className="bg-gradient-to-br from-green-100 to-teal-100 p-8 rounded-3xl shadow-lg">
              <div dangerouslySetInnerHTML={{ __html: svgContent }} className="w-48 h-48" />
            </div>
          </div>

          <div className="mb-6">
            <button
              onClick={downloadAll}
              disabled={generating}
              className="w-full bg-gradient-to-r from-green-500 to-teal-500 text-white py-4 rounded-xl font-semibold hover:from-green-600 hover:to-teal-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg flex items-center justify-center gap-2"
            >
              <Download size={20} />
              {generating ? 'Generating...' : 'Download All Sizes'}
            </button>
            <p className="text-sm text-gray-500 mt-2 text-center">
              Downloads all required sizes automatically (one at a time)
            </p>
          </div>

          <div className="border-t pt-6">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">Individual Sizes</h2>
            <div className="grid gap-3">
              {iconSizes.map((icon, idx) => (
                <div key={idx} className="bg-gray-50 rounded-lg p-4">
                  <div className="flex justify-between items-center mb-2">
                    <div>
                      <h3 className="font-semibold text-gray-700">{icon.name}</h3>
                      <p className="text-sm text-gray-500">{icon.size}pt base size</p>
                    </div>
                  </div>
                  <div className="flex gap-2 flex-wrap">
                    {icon.scale.map((scale) => {
                      const actualSize = scale === 1 ? icon.size : icon.size * scale / 2;
                      const finalSize = scale === 1 ? icon.size : icon.size * scale / 2;
                      return (
                        <button
                          key={scale}
                          onClick={() => downloadIcon(finalSize, scale > 1 ? `@${scale}x` : '')}
                          disabled={generating}
                          className="bg-white border-2 border-gray-200 px-4 py-2 rounded-lg hover:border-green-500 hover:bg-green-50 transition-all disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium flex items-center gap-2"
                        >
                          <Download size={14} />
                          {finalSize}x{finalSize}px {scale > 1 ? `(@${scale}x)` : ''}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-8 bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
            <h3 className="font-semibold text-blue-900 mb-2">Usage Instructions:</h3>
            <ol className="text-sm text-blue-800 space-y-1 list-decimal list-inside">
              <li>Download all sizes using the button above</li>
              <li>Open your Xcode project</li>
              <li>Navigate to Assets.xcassets → AppIcon</li>
              <li>Drag and drop each PNG into its corresponding slot</li>
              <li>Build and run your app to see the icon!</li>
            </ol>
          </div>
        </div>
      </div>

      <canvas ref={canvasRef} style={{ display: 'none' }} />
    </div>
  );
};

export default IOSIconGenerator;