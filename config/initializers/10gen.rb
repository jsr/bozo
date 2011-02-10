
# load the 10gen settings file
settings_file = File.join(Rails.root, "config", "10gen_settings.yml")

SETTINGS_10GEN = File.exists?(settings_file) ? YAML.load_file(settings_file) : {}
