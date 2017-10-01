# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'octokit'
require 'yaml'

require_relative 'reporter.rb'

# Standard reporters
require_relative 'report_docs.rb'
require_relative 'report_binary_files.rb'
require_relative 'report_license.rb'

# Remove any control characters that XML dislikes
#
# I ADDED \x0 to this
# [#x1-#x8], [#xB-#xC], [#xE-#x1F], [#x7F-#x84], [#x86-#x9F], [#xFDD0-#xFDDF],
#
# Not implemented yet
# [#x1FFFE-#x1FFFF], [#x2FFFE-#x2FFFF], [#x3FFFE-#x3FFFF],
# [#x4FFFE-#x4FFFF], [#x5FFFE-#x5FFFF], [#x6FFFE-#x6FFFF],
# [#x7FFFE-#x7FFFF], [#x8FFFE-#x8FFFF], [#x9FFFE-#x9FFFF],
# [#xAFFFE-#xAFFFF], [#xBFFFE-#xBFFFF], [#xCFFFE-#xCFFFF],
# [#xDFFFE-#xDFFFF], [#xEFFFE-#xEFFFF], [#xFFFFE-#xFFFFF],
# [#x10FFFE-#x10FFFF]
def stripRestricted(txt)
  return txt.tr("\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f-\u0084\u0086-\u009f\ufdd0-\ufddf", '')
end

def get_reporter_instances(dashboard_config)
  reports = dashboard_config['reports']
  report_path = dashboard_config['report-path']

  # Use the report.path to add others
  if(report_path)
    # TODO: List files matching review_* and automatically require all of them.
    #       Create scopes so they don't affect each other?
    # TODO: Alternatively, at least add a filter so it is only loading the requested reporters
    report_path.each do |report_dir|
      if(Dir.exists?(report_dir))
        Dir.glob(File.join(report_dir, 'report_*')).each do |reportFile|
          require "#{reportFile}"
        end
      end
    end
  end
  
  report_instances=[]
  if(reports)
    reports.each do |reportName|
      clazz = Object.const_get(reportName)
      report_instances<<clazz.new
    end
  end
  return report_instances
end

def review_source(context)

  owners = context.dashboard_config['organizations+logins']
  data_directory = context.dashboard_config['data-directory']
  scratch_dir="#{data_directory}/scratch"

  report_instances=get_reporter_instances(context.dashboard_config)
 
  unless(File.exists?("#{data_directory}/review-xml/"))
    Dir.mkdir("#{data_directory}/review-xml/")
  end

  owners.each do |owner|
    context.feedback.print "  #{owner} "
  
    unless(File.exists?("#{data_directory}/review-xml/#{owner}/"))
      Dir.mkdir("#{data_directory}/review-xml/#{owner}/")
    end

    repos = context.repositories(owner)

    repos.each do |repo|
      unless File.exists?("#{scratch_dir}/#{repo.full_name}")
        next
      end
  
      review_file=File.open("#{data_directory}/review-xml/#{repo.full_name}.xml", 'w')

      report="    <reports org='#{owner}' name='#{repo.name}'>\n"

      report_instances.each do |report_obj|
        txt = report_obj.report(context, repo, "#{scratch_dir}/#{repo.full_name}").to_s
        if(txt)
          txt=txt.encode('UTF-8', 'binary', undef: :replace, replace: '')
          txt=stripRestricted(txt)
        end
        report << txt
      end

      report << "    </reports>\n"
      review_file.puts report
      review_file.close

      context.feedback.print '.'
    end
    context.feedback.print "\n"
  end
  
end
