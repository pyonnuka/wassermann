class Shop
  include ActiveModel::Model
  #定数
  REPT_URL='http://api.gnavi.co.jp/ouen/ver1/PhotoSearch'
  REST_URL='http://api.gnavi.co.jp/ver1/RestSearchAPI/'
  KEY_ID = ENV["GNAVI_KEYID"]
  NO_IMAGE = '/images/noimage.png'

  #アクセッサ定義
  attr_reader:name
  attr_reader:url
  attr_reader:comment
  attr_reader:img_url
  attr_reader:keyword

  def initialize(name, url, comment, img_url, keyword)
    @name = name
    @url = url
    @comment = comment
    @img_url = img_url
    @keyword = keyword
  end

  #口コミAPIを使用して店リストを取得
  #2つ目の戻り値で取得可能なページ数を返す
  #デフォルトのrange=3は1000m範囲
  def self.search_reputation(loc_name, range = 3, offset_page = 1)
    result = get_json_of_reputation_api(loc_name, range, offset_page)
    if result.nil?
      return nil
    end
    data = JSON.parse (result)

    shops = Array.new

    #エラーまたは0件
    if data['error'] then
      p data['error']['code']
      return shops
    end

    pages = 0
    count = 0
    data['response'].each do |key, value|
      if key == 'total_hit_count'
        count = value.to_i
        pages = count / 50 + 1 #ページ数を算出
      elsif key =~ /[0-9]+/ #keyが数字のとき
        s = value['photo']
        #画像URLの取得
        #ここの画像のサイズどうしよう？ url_1024, url_320, url_240, url_200がある
        img_url = s['image_url']['url_320']
        if img_url.empty?
          next
        end

        shop = Shop.new(s['shop_name'], s['shop_url'], s['comment'], img_url, '')
        if shop.comment.present? #コメントがあれば詰める
          shops.push(shop)
        end
      end
    end
    p shops.length
    return shops
  end

  #レストランAPIを使用して店リストを取得
  #2つ目の戻り値で取得可能なページ数を返す
  #デフォルトのrange=3は1000m範囲
  def self.search(loc_name, freewords = '', range = 3, page = 1)
    result = get_json_of_restaurant_api(loc_name, freewords, range, page)
    if result.nil?
      return nil
    end
    data = JSON.parse(result)

    shops = Array.new

    #エラーまたは0件
    if data['error'] then
      puts data['error']['code']
      return shops
    end

    count = data['total_hit_count'].to_i
    pages = count / 50 + 1 #ページ数を算出

    #1件
    if count == 1
      unless (shop = build(data['rest'])) == nil
        shops.push(shop)
      end
      p shops.length
      return shops
    end

    #2件以上
    data['rest'].each do |rest|
      unless (shop = build(rest)) == nil
        shops.push(shop)
      end
    end
    return shops
  end

  private #===== 以下プライベートメソッド =====

  #コンストラクタ railsのmodelに倣う
  def self.build(rest)
    p rest
    img_url = ''
    img_url1 = rest['image_url']['shop_image1']
    img_url2 = rest['image_url']['shop_image2']
    if img_url1.present?
      img_url = img_url1
    elsif img_url2.present?
      img_url = img_url2
    else
      return nil;
    end

    keywords = rest['code']['category_name_s']
    keywords.delete_if {
      |word| word.is_a? Hash
    }

    return Shop.new(rest['name'], rest['url'], rest['pr']['short'], img_url, keywords)
  end

  #口コミAPIからJSON型データを取得する
  def self.get_json_of_reputation_api(loc_name, range, offset_page)
    location = Location.find_by(name: loc_name)
    if location.blank?
      return nil
    end
    latitude_degree = location.latitude
    longitude_degree = location.longitude

    get_data = {
      'keyid' => KEY_ID,
      'latitude' => latitude_degree,
      'longitude' => longitude_degree,
      'range' => range, #距離
      'offset_page' => offset_page, #ページ
      'hit_per_page' => 50, #1回の検索店舗数
      'order' => 'vote_date', #投稿日時が近いものでソート
      'format' => 'json'
    }
    client = HTTPClient.new
    begin
      return client.get_content(REPT_URL, get_data)
    rescue HTTPClient::BadResponseError => e
      p e
    rescue HTTPClient::TimeoutError => e
      p e
    end
  end

  #レストランAPIからJSONデータを取得する
  def self.get_json_of_restaurant_api(loc_name, freewords, range, offset_page)
    location = Location.find_by(name: loc_name)
    if location.blank?
      return nil
    end
    latitude_degree = location.latitude
    longitude_degree = location.longitude

    get_data = {
      'keyid' => KEY_ID,
      'input_coordinates_mode' => 2, #世界標準系指定
      'latitude' => latitude_degree,
      'longitude' => longitude_degree,
      'range' => range, #距離
      'offset_page' => offset_page, #ページ
      'freeword' => freewords,
      'freeword_condition' => 2, #OR検索
      'hit_per_page' => 50, #1回の検索店舗数
      'lunch' => 1, #ランチ営業あり
      'format' => 'json'
    }
    client = HTTPClient.new
    begin
      return client.get_content(REST_URL, get_data)
    rescue HTTPClient::BadResponseError => e
      p e
    rescue HTTPClient::TimeoutError => e
      p e
    end
  end
end
