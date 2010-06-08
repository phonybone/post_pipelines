# Include hook code here

# For some reason we get a really weird ruby error here unless this next line is present.  
# So don't delete it, or be prepared for weirdness if you  do.
#require 'rnaseq_pipeline'

# Add to AppConfig:
config.after_initialize do
  AppConfig.load('vendor/plugins/post_pipelines/config/application.yml','common')
end
