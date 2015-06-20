module SpecUtilities

  def random_string
    (0...24).map{ ('a'..'z').to_a[rand(26)] }.join
  end

end