-- Flyway Migration V2: Seed Sample Dictionary Words
INSERT INTO word_entries (word, phonetic, part_of_speech, definition, example) VALUES
('computer', '/kəmˈpjuːtər/', 'noun', 'An electronic device for processing data.', 'Modern computers can execute billions of instructions per second.'),
('devops', '/ˈdɛv.ɒps/', 'noun', 'A set of practices combining software development and IT operations to shorten the development lifecycle.', 'Adopting DevOps principles increased our deployment frequency dramatically.'),
('container', '/kənˈteɪ.nər/', 'noun', 'A standard unit of software that packages code and all its dependencies so the application runs reliably.', 'Docker containers allow applications to run consistently across any environment.'),
('pipeline', '/ˈpaɪp.laɪn/', 'noun', 'A set of automated processes that allow developers to build, test, and deploy software reliably.', 'The CI/CD pipeline caught a syntax error before reaching production.'),
('database', '/ˈdeɪ.tə.beɪs/', 'noun', 'An organized collection of data stored and accessed electronically.', 'PostgreSQL is a powerful, open-source object-relational database system.'),
('cloud', '/klaʊd/', 'noun', 'The on-demand availability of computer system resources, especially data storage and computing power.', 'Migrating our services to the cloud enabled elastic scaling.'),
('software', '/ˈsɒft.weər/', 'noun', 'The programs and other operating information used by a computer.', 'Good software engineering emphasizes clean architecture and automated testing.'),
('network', '/ˈnet.wɜːk/', 'noun', 'A group of two or more computer systems linked together.', 'Docker creates an internal bridge network for inter-container communication.'),
('kubernetes', '/ˌkuː.bərˈnɛ.tiz/', 'noun', 'An open-source container orchestration system for automating application deployment and management.', 'Kubernetes automates rollout and scaling of container clusters.'),
('algorithm', '/ˈæl.ɡə.rɪ.ðəm/', 'noun', 'A step-by-step procedure or set of rules for solving a problem.', 'The search algorithm finds dictionary terms in logarithmic time.')
ON CONFLICT (word) DO NOTHING;
