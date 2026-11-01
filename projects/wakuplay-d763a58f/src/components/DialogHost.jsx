import { useEffect, useState } from 'react'
import { subscribeDialog } from '../lib/dialog'
import Icon from './Icon'

export default function DialogHost() {
  const [d, setD] = useState(null)
  useEffect(() => subscribeDialog(setD), [])
  if (!d) return null
  return (
    <div className="cl-bg center wp-dlg-bg" style={{ zIndex: 400 }} onClick={() => d.resolve(false)}>
      <div key={d.id} className={`cl-confirm wp-dlg ${d.danger ? 'danger' : ''}`} role="alertdialog" aria-modal="true" aria-label={d.title} onClick={(e) => e.stopPropagation()}>
        <span className="wp-dlg-ic" aria-hidden="true"><Icon name={d.danger ? 'trash' : 'check'} size={26} /></span>
        <h3>{d.title}</h3>
        <p>{d.body}</p>
        <div className="cl-confirm-btns">
          <button className="cl-btn ghost" onClick={() => d.resolve(false)}>{d.no}</button>
          <button className={`cl-btn ${d.danger ? 'danger' : 'primary'}`} onClick={() => d.resolve(true)}>{d.yes}</button>
        </div>
      </div>
    </div>
  )
}
