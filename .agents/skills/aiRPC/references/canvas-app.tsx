// aiRPC canvas — drop-in App.tsx for a `npm create tldraw@latest` scaffold.
// Renders the aiRPC manifest as tldraw blocks with per-block prompt inputs;
// Enter sends the call (block identity + prompt) to the bridge; the events
// long-poll paints ack chips back onto the blocks. Syntax-checked only —
// build against the scaffold's installed tldraw version before deploying.
import { useEffect, useRef, useState } from 'react'
import {
	Editor,
	HTMLContainer,
	ShapeUtil,
	Tldraw,
	TLBaseShape,
	TLShapeId,
	createShapeId,
	toRichText,
	useEditor,
} from 'tldraw'
import 'tldraw/tldraw.css'

const BRIDGE = 'http://127.0.0.1:7331'
const SESSION = 'main'
const CARD_W = 380
const CARD_H = 220
const LANE_GAP = 60

type AiRpcBlockProps = {
	w: number
	h: number
	blockId: string
	path: string
	anchor: string
	title: string
	kind: string
	digest: string
	status: string
	summary: string
	note: string
	body: string
}

type AiRpcBlockShape = TLBaseShape<'aiRpcBlock', AiRpcBlockProps>

class AiRpcBlockShapeUtil extends ShapeUtil<AiRpcBlockShape> {
	static override type = 'aiRpcBlock' as const

	getDefaultProps(): AiRpcBlockProps {
		return {
			w: CARD_W,
			h: CARD_H,
			blockId: '',
			path: '',
			anchor: '',
			title: '',
			kind: 'wiki',
			digest: '',
			status: 'new',
			summary: '',
			note: '',
			body: '',
		}
	}

	override canEdit() {
		return true
	}

	getGeometry() {
		return this.app.getGeometry('rectangle') // placeholder; scaffold ships rect geometry
	}

	component(shape: AiRpcBlockShape) {
		return (
			<HTMLContainer style={{ pointerEvents: 'all' }}>
				<AiRpcCard shape={shape} />
			</HTMLContainer>
		)
	}

	indicator(shape: AiRpcBlockShape) {
		return <rect width={shape.props.w} height={shape.props.h} rx={8} />
	}
}

function AiRpcCard({ shape }: { shape: AiRpcBlockShape }) {
	const editor = useEditor()
	const { blockId, path, anchor, title, kind, digest, status, summary, note, body } = shape.props
	const [text, setText] = useState('')
	const busy = useRef(false)

	async function send() {
		const prompt = text.trim()
		if (!prompt || busy.current) return
		busy.current = true
		setText('')
		editor.updateShape<AiRpcBlockShape>({
			id: shape.id,
			type: 'aiRpcBlock',
			props: { status: 'sent', summary: 'waiting for agent…' },
		})
		try {
			const res = await fetch(`${BRIDGE}/rpc`, {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({
					v: 1,
					kind: 'call',
					session: SESSION,
					block_id: blockId,
					path,
					anchor,
					digest,
					prompt,
				}),
			})
			if (!res.ok) throw new Error(`HTTP ${res.status}`)
		} catch (e) {
			editor.updateShape<AiRpcBlockShape>({
				id: shape.id,
				type: 'aiRpcBlock',
				props: { status: 'refused', summary: `call failed: ${String(e)}` },
			})
		} finally {
			busy.current = false
		}
	}

	return (
		<div
			style={{
				width: '100%',
				height: '100%',
				background: '#ffffff',
				border: '1px solid #e1e5e9',
				borderRadius: 8,
				padding: 10,
				display: 'flex',
				flexDirection: 'column',
				gap: 6,
				fontFamily: 'ui-sans-serif, system-ui',
				overflow: 'hidden',
			}}
		>
			<div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
				<b style={{ fontSize: 13 }}>{title || path}</b>
				<span
					style={{
						fontSize: 10,
						padding: '2px 6px',
						borderRadius: 999,
						background: status === 'done' ? '#d1fae5' : status === 'refused' || status === 'stale' ? '#fee2e2' : '#e0e7ff',
						whiteSpace: 'nowrap',
					}}
				>
					{kind} · {status}
				</span>
			</div>
			<div style={{ fontSize: 10, color: '#64748b' }}>
				{path}
				{anchor ? ` › ${anchor}` : ''} · {digest}
			</div>
			{summary ? <div style={{ fontSize: 11 }}>{summary}</div> : null}
			{note ? <div style={{ fontSize: 11, color: '#475569', fontStyle: 'italic' }}>{note}</div> : null}
			<pre
				style={{
					flex: 1,
					margin: 0,
					fontSize: 10,
					overflow: 'auto',
					whiteSpace: 'pre-wrap',
					background: '#f8fafc',
					borderRadius: 4,
					padding: 6,
				}}
			>
				{body.slice(0, 1200)}
			</pre>
			<textarea
				value={text}
				placeholder="Describe the edit… (Enter sends, Shift+Enter newline)"
				onChange={(e) => setText(e.target.value)}
				onKeyDown={(e) => {
					if (e.key === 'Enter' && !e.shiftKey) {
						e.preventDefault()
						void send()
					}
				}}
				style={{ resize: 'none', height: 40, fontSize: 11, borderRadius: 4, padding: 4 }}
			/>
		</div>
	)
}

function statusToChip(a: { status: string; summary?: string; note?: string }) {
	return { status: a.status, summary: a.summary ?? '', note: a.note ?? '' }
}

function AiRpcApp() {
	const editor = useEditor()
	const seqRef = useRef(0)

	// Load the manifest and lay blocks out in lanes; then paint acks as they arrive.
	useEffect(() => {
		let alive = true
		async function load() {
			const res = await fetch(`${BRIDGE}/state`)
			const state = await res.json()
			if (!alive || !state.manifest) return
			const laneY = new Map<number, number>()
			for (const b of state.manifest.blocks as Array<AiRpcBlockProps & { lane: number }>) {
				const lane = b.lane ?? 0
				const y = laneY.get(lane) ?? 0
				laneY.set(lane, y + CARD_H + 20)
				editor.createShape<AiRpcBlockShape>({
					id: createShapeId(b.id),
					type: 'aiRpcBlock',
					x: lane * (CARD_W + LANE_GAP),
					y,
					props: {
						w: CARD_W,
						h: CARD_H,
						blockId: b.id,
						path: b.path,
						anchor: b.anchor,
						title: b.title,
						kind: b.kind,
						digest: b.digest,
						status: 'new',
						summary: '',
						note: '',
						body: b.body,
					},
				})
			}
			for (const ev of state.events as Array<{ kind: string; seq: number }>) {
				seqRef.current = Math.max(seqRef.current, ev.seq ?? 0)
			}
		}
		async function events() {
			while (alive) {
				const res = await fetch(`${BRIDGE}/events?after=${seqRef.current}`).catch(() => null)
				if (!res || !res.ok) {
					const { promise, resolve } = Promise.withResolvers<void>()
					setTimeout(resolve, 2000)
					await promise
					continue
				}
				const rows = await res.json()
				for (const row of rows) {
					seqRef.current = Math.max(seqRef.current, row.seq ?? 0)
					if (row.kind !== 'ack') continue
					const shapeId = createShapeId(row.block_id)
					const shape = editor.getShape<AiRpcBlockShape>(shapeId)
					if (!shape) continue
					editor.updateShape<AiRpcBlockShape>({
						id: shapeId,
						type: 'aiRpcBlock',
						props: statusToChip(row),
					})
				}
			}
		}
		void load()
		void events()
		return () => {
			alive = false
		}
	}, [editor])

	return null
}

export default function App() {
	const handleMount = (editor: Editor) => {
		editor.createShape({
			type: 'text',
			x: 0,
			y: -260,
			props: { richText: toRichText('aiRPC — type into a block, Enter sends the call') },
		})
	}
	return (
		<div style={{ position: 'fixed', inset: 0 }}>
			<Tldraw shapeUtils={[AiRpcBlockShapeUtil]} onMount={handleMount}>
				<AiRpcApp />
			</Tldraw>
		</div>
	)
}
