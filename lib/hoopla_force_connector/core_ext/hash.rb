# Some hash helpers for mapping and filtering on keys
class Hash
  def map_to_hash(&block)
    ret = Hash[*(map(&block).flatten(1))]
    ret.without_keys(nil)
  end

  def without_keys(*keys)
    reject { |k, v| keys.include?(k) }
  end
end
