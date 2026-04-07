# Podcast Search Feature

## Summary

Add a podcast search feature to the browse page. Users click a "Search Podcasts" button that opens a modal with a debounced search input. Results come from the iTunes Search API (proxied through sp_server). Clicking a result navigates to the editor page with the podcast's feed URL pre-filled.

## Architecture

### Backend: `GET /api/podcasts/search?term=<query>&limit=25`

- New route handler in `crates/sp_server/src/routes/podcast.rs`
- Proxies to `https://itunes.apple.com/search?media=podcast&term=<query>&limit=25`
- Uses existing `reqwest::Client` from `AppState.http_client`
- Validates `term` is non-empty (400 if empty)
- iTunes errors returned as 502 (Bad Gateway)
- Passes through the iTunes JSON response as-is:

```json
{
  "resultCount": 1,
  "results": [
    {
      "trackName": "Podcast Name",
      "artistName": "Author",
      "artworkUrl100": "https://...",
      "feedUrl": "https://...",
      "trackCount": 245,
      "primaryGenreName": "Technology"
    }
  ]
}
```

### Frontend: Search Modal

- Trigger: "Search Podcasts" button on the browse page (alongside existing "Create New")
- Modal component: `packages/sp_react/src/components/podcast-search/search-dialog.tsx`
- Debounced input (300ms) triggers `useSearchPodcasts(term)` query hook
- Results displayed as compact list: artwork (48px) + name + author + genre
- Clicking a result closes the modal and navigates to `/editor?feedUrl=<encodedUrl>&displayName=<trackName>`
- Loading and empty states handled
- 25 results max

### Data Flow

1. User clicks "Search Podcasts" on browse page
2. Modal opens with search input (auto-focused)
3. User types podcast name, debounced at 300ms
4. React calls `GET /api/podcasts/search?term=...`
5. sp_server proxies to iTunes Search API
6. Results rendered as list in modal
7. User clicks a result
8. Modal closes, navigates to `/editor?feedUrl=<url>&displayName=<name>`
9. Editor page reads `feedUrl` and `displayName` from search params and pre-fills the config

### Integration with Editor

The editor index route (`/editor`) already exists for creating new patterns. The `feedUrl` search param will be read and used to pre-populate the feed URL field, giving the user a head start on pattern creation.

## Files to Create/Modify

### New files
- `crates/sp_server/src/routes/podcast.rs` - Search handler
- `packages/sp_react/src/components/podcast-search/search-dialog.tsx` - Search modal
- `packages/sp_react/src/components/podcast-search/search-result-item.tsx` - Result row

### Modified files
- `crates/sp_server/src/routes/mod.rs` - Register new route
- `packages/sp_react/src/api/queries.ts` - Add `useSearchPodcasts` hook
- `packages/sp_react/src/schemas/api-schema.ts` - Add `PodcastSearchResult` schema
- `packages/sp_react/src/routes/browse.tsx` - Add search button + modal
- `packages/sp_react/src/routes/editor.index.tsx` - Read `feedUrl` search param

## Testing

### Rust
- Unit test for query parameter validation (empty term)
- Integration test for search handler with mocked HTTP client

### React
- Component test for search dialog rendering and interaction
- Hook test for debounced search query

## Out of Scope
- Caching iTunes results (can add later)
- Podcast details/preview before navigating to editor
- Search by feed URL or other criteria
