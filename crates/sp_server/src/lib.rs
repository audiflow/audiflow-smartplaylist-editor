// sp_server: Axum HTTP server
pub mod app;
pub mod routes;
pub mod services;
pub mod static_files;

pub use static_files::has_embedded_index;
