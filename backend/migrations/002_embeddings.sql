CREATE TABLE chunk_embeddings (
  chunk_id TEXT NOT NULL REFERENCES document_chunks(id) ON DELETE CASCADE,
  model TEXT NOT NULL,
  dimensions INTEGER NOT NULL CHECK(dimensions > 0),
  vector TEXT NOT NULL,
  PRIMARY KEY(chunk_id, model)
);
