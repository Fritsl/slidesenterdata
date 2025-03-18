
CREATE INDEX IF NOT EXISTS idx_notes_tree 
ON notes(project_id, parent_id, position);

CREATE INDEX IF NOT EXISTS idx_notes_hierarchy 
ON notes(parent_id, project_id) 
INCLUDE (position);
