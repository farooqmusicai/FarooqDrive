import React from 'react';

type UploadItem = { id: string; name: string; progress: number; status: 'uploading'|'done'|'error'; error?: string };
export function UploadPanel({items}:{items:UploadItem[]}) {
  if (!items.length) return null;
  return <div className="upload-panel">
    <div className="upload-title">Uploads</div>
    {items.map(item => <div className="upload-row" key={item.id}>
      <div className="upload-meta"><span title={item.name}>{item.name}</span><b>{item.status==='done' ? '✓' : item.status==='error' ? '!' : `${item.progress}%`}</b></div>
      <div className="bar"><div className="bar-fill" style={{width:`${item.progress}%`}}/></div>
      {item.error && <small>{item.error}</small>}
    </div>)}
  </div>
}
