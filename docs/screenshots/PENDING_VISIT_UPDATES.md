# Pending visit updates for docs screenshot specs

Summary
-------

- Total generated screenshot spec files: 172
- Specs already configured with non-root `visit` targets: 2
- Specs that still need a meaningful `visit` target (currently `visit '/'` placeholder): ~170

Configured specs (already target a non-root path)
------------------------------------------------

- spec/docs_screenshots/docs_developers_architecture_polymorphic_and_sti_spec.rb  (visit '/admin/models')
- spec/docs_screenshots/docs_polymorphic_and_sti_spec.rb                          (visit '/admin/models')

What needs doing
-----------------

1. Review each spec under `spec/docs_screenshots/` and replace the placeholder `visit '/'` with the specific path to capture for that doc. Each spec contains two example captures (desktop + mobile). Update the `visit` and any interaction steps so the page renders as shown in the doc.
2. If a doc does not require a screenshot, add `<!-- NO_SCREENSHOT -->` to the corresponding markdown doc so the generator will skip it on future runs.
3. Use `docs/screenshot_mappings.yml` to provide bulk mappings (doc → visit path). Then run `bin/apply_screenshot_mappings` to apply them automatically to the skeleton specs.

Full list of generated spec files
-------------------------------

Note: files marked with (configured) already have a non-root `visit` target. All other files currently contain the placeholder `visit '/'` and need a visit URL or intentional opt-out.

- spec/docs_screenshots/docs_developers_architecture_models_and_concerns_spec.rb
- spec/docs_screenshots/docs_community_organizers_readme_spec.rb
- spec/docs_screenshots/docs_developers_systems_community_social_system_spec.rb
- spec/docs_screenshots/docs_end_users_user_management_guide_spec.rb
- spec/docs_screenshots/docs_developers_systems_events_system_spec.rb
- spec/docs_screenshots/docs_users_events_user_guide_spec.rb
- spec/docs_screenshots/docs_developers_systems_mapping_system_spec.rb
- spec/docs_screenshots/docs_implementation_current_plans_block_management_interface_acceptance_criteria_spec.rb
- spec/docs_screenshots/docs_assessments_application_assessment_2025_08_27_spec.rb
- spec/docs_screenshots/docs_shared_democratic_by_design_spec.rb
- spec/docs_screenshots/docs_developers_readme_spec.rb
- spec/docs_screenshots/docs_shared_readme_spec.rb
- spec/docs_screenshots/docs_legal_compliance_readme_spec.rb
- spec/docs_screenshots/docs_meta_readme_spec.rb
- spec/docs_screenshots/docs_developers_architecture_rbac_overview_spec.rb
- spec/docs_screenshots/docs_joatu_agreements_spec.rb
- spec/docs_screenshots/docs_readme_spec.rb
- spec/docs_screenshots/docs_ui_resource_toolbar_spec.rb
- spec/docs_screenshots/docs_shared_privacy_principles_spec.rb
- spec/docs_screenshots/docs_developers_systems_readme_conversations_spec.rb
- spec/docs_screenshots/docs_stakeholder_documentation_structure_spec.rb
- spec/docs_screenshots/docs_implementation_readme_spec.rb
- spec/docs_screenshots/docs_end_users_exchange_process_spec.rb
- spec/docs_screenshots/docs_production_deployment_dokku_spec.rb
- spec/docs_screenshots/docs_development_dev_setup_spec.rb
- spec/docs_screenshots/docs_meta_documentation_inventory_spec.rb
- spec/docs_screenshots/docs_developers_systems_security_protection_system_spec.rb
- spec/docs_screenshots/docs_content_moderators_readme_spec.rb
- spec/docs_screenshots/docs_ui_help_banners_spec.rb
- spec/docs_screenshots/docs_ui_navigation_sidebar_guide_spec.rb
- spec/docs_screenshots/docs_meta_stakeholder_documentation_structure_spec.rb
- spec/docs_screenshots/docs_implementation_current_plans_community_social_system_acceptance_criteria_spec.rb
- spec/docs_screenshots/docs_joatu_requests_spec.rb
- spec/docs_screenshots/docs_developers_resource_controller_patterns_spec.rb
- spec/docs_screenshots/docs_developers_development_i18n_todo_spec.rb
- spec/docs_screenshots/docs_developers_systems_content_management_spec.rb
- spec/docs_screenshots/docs_joatu_categories_spec.rb
- spec/docs_screenshots/docs_meta_documentation_assessment_2025_08_23_spec.rb
- spec/docs_screenshots/docs_production_external_services_to_configure_spec.rb
- spec/docs_screenshots/docs_developers_systems_navigation_system_spec.rb
- spec/docs_screenshots/docs_screenshots_readme_spec.rb
- spec/docs_screenshots/docs_polymorphic_and_sti_spec.rb (configured)
- spec/docs_screenshots/docs_diagram_rendering_spec.rb
- spec/docs_screenshots/docs_implementation_plan_template_spec.rb
- spec/docs_screenshots/docs_developers_systems_caching_performance_system_spec.rb
- spec/docs_screenshots/docs_platform_organizers_user_management_spec.rb
- spec/docs_screenshots/docs_shared_roles_and_permissions_spec.rb
- spec/docs_screenshots/docs_developers_systems_ai_integration_system_spec.rb
- spec/docs_screenshots/docs_shared_escalation_matrix_spec.rb
- spec/docs_screenshots/docs_meta_documentation_assessment_spec.rb
- spec/docs_screenshots/docs_developers_systems_notifications_system_spec.rb
- spec/docs_screenshots/docs_developers_systems_conversations_messaging_system_spec.rb
- spec/docs_screenshots/docs_community_organizers_community_management_spec.rb
- spec/docs_screenshots/docs_joatu_offers_spec.rb
- spec/docs_screenshots/readme_spec.rb
- spec/docs_screenshots/docs_developers_development_automatic_test_configuration_spec.rb
- spec/docs_screenshots/docs_joatu_matching_and_notifications_spec.rb
- spec/docs_screenshots/docs_meta_documentation_restructure_plan_spec.rb
- spec/docs_screenshots/docs_support_staff_readme_spec.rb
- spec/docs_screenshots/docs_developers_systems_geography_system_spec.rb
- spec/docs_screenshots/example_screenshots_spec.rb
- spec/docs_screenshots/docs_platform_organizers_host_dashboard_extensions_spec.rb
- spec/docs_screenshots/docs_developers_architecture_polymorphic_and_sti_spec.rb (configured)
- spec/docs_screenshots/docs_developers_resource_permitted_attributes_spec.rb
- spec/docs_screenshots/docs_developers_systems_metrics_system_spec.rb
- spec/docs_screenshots/docs_developers_systems_agreements_system_spec.rb
- spec/docs_screenshots/docs_end_users_readme_spec.rb
- spec/docs_screenshots/docs_developers_systems_accounts_and_invitations_spec.rb
- spec/docs_screenshots/docs_diagrams_readme_spec.rb
- spec/docs_screenshots/docs_implementation_templates_tdd_acceptance_criteria_template_spec.rb
- spec/docs_screenshots/docs_end_users_whats_new_security_and_privacy_aug_2025_spec.rb
- spec/docs_screenshots/docs_implementation_current_plans_community_social_system_implementation_plan_spec.rb
- spec/docs_screenshots/docs_models_and_concerns_spec.rb
- spec/docs_screenshots/docs_implementation_templates_system_documentation_template_spec.rb
- spec/docs_screenshots/docs_table_of_contents_spec.rb
- spec/docs_screenshots/docs_production_raspberry_pi_setup_spec.rb
- spec/docs_screenshots/docs_platform_organizers_readme_spec.rb

If you'd like I can:

- generate a CSV or markdown checklist marking each spec as "needs update" so you can claim them in a sprint.
- apply a provided `docs/screenshot_mappings.yml` file to fill `visit` targets in bulk (I already have `bin/apply_screenshot_mappings` in the repo). Provide the YAML and I'll run the applier.
- open and edit a short list of specs you point me to (or pick the top-10 highest-priority docs) and set reasonable `visit` URLs and interactions, then run the screenshot runner for those.

Next steps I'll take if you confirm one of the above options.
