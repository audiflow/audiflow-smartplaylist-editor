use std::convert::Infallible;

use axum::extract::State;
use axum::response::sse::{Event, Sse};
use tokio_stream::StreamExt;
use tokio_stream::wrappers::BroadcastStream;

use crate::app::SharedState;

/// GET /api/events -- SSE stream of file change events.
///
/// Each event is formatted as `data: {"type": "...", "path": "..."}\n\n`
/// per the SSE spec.
pub async fn sse_events(
    State(state): State<SharedState>,
) -> Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>> {
    let rx = state.file_watcher.subscribe();
    let stream = BroadcastStream::new(rx).filter_map(|result| {
        match result {
            Ok(change_event) => {
                let json = serde_json::to_string(&change_event).ok()?;
                Some(Ok(Event::default().data(json)))
            }
            // Skip lagged messages
            Err(_) => None,
        }
    });

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(std::time::Duration::from_secs(30))
            .text("keep-alive"),
    )
}
