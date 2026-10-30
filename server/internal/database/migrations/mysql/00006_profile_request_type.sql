-- +goose Up
ALTER TABLE edit_requests
    DROP CHECK chk_edit_request_type;

ALTER TABLE edit_requests
    ADD CONSTRAINT chk_edit_request_type CHECK (
        request_type IN (
            'create_person',
            'update_person',
            'update_person_profile',
            'archive_person',
            'add_parent_child',
            'end_parent_child',
            'add_spouse',
            'end_spouse'
        )
    );

-- +goose Down
ALTER TABLE edit_requests
    DROP CHECK chk_edit_request_type;

ALTER TABLE edit_requests
    ADD CONSTRAINT chk_edit_request_type CHECK (
        request_type IN (
            'create_person',
            'update_person',
            'archive_person',
            'add_parent_child',
            'end_parent_child',
            'add_spouse',
            'end_spouse'
        )
    );
