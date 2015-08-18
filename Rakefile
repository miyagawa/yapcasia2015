desc "build static files"
task :build do
  system "ruby render.rb > index.html"
end

desc "refresh JSON files"
task :json do
  system "curl", "-s", "-o", "day0.json", "http://yapcasia.org/2015/talk/schedule?format=json&date=2015-08-20"
  system "curl", "-s", "-o", "day1.json", "http://yapcasia.org/2015/talk/schedule?format=json&date=2015-08-21"
  system "curl", "-s", "-o", "day2.json", "http://yapcasia.org/2015/talk/schedule?format=json&date=2015-08-22"
end
