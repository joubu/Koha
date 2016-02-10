ALTER TABLE letter ADD is_tt TINYINT(1) NOT NULL DEFAULT 0 AFTER message_transport_type;

INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES
('TemplateToolkitNotices',0,'','Enable the ability to use Template Toolkit syntax in slips and notices','YesNo');
