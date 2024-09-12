class GameController < ApplicationController
  def index
    #@paijun = majon_pais.sample(majon_pais.size)
  end
  
  def test
    tileAll = Tile.all()
    @rest_tiles = tileAll.sample(14 + 30)
    
    # sliceメソッドのびっくりマーク。
    #haipai = @rest_tiles.slice!(0..13)
    if Rails.cache.exist?('discard_tiles')
      Rails.cache.clear('discard_tiles')
    end
    
    @hand_tiles = @rest_tiles.slice!(0..12)
    @next_tile = @rest_tiles.slice!(0)
    
    Rails.cache.write('hand_tiles', @hand_tiles)
    Rails.cache.write('rest_tiles', @rest_tiles)
    
    if Rails.cache.exist?('discard_tiles')
      @discard_tiles = Rails.cache.read('discard_tiles')
    else
      @discard_tiles = Array.new()
    end
    #binding.pry()
  end
  
  # 牌の種類をデータベースに登録。
  # キーワードajax(非同期通信) rails jsファイル
  def discard
    @hand_tiles = Rails.cache.read('hand_tiles')
    @rest_tiles = Rails.cache.read('rest_tiles')
    @discard_tiles = Array.new()
    @next_tile = @rest_tiles.slice!(0)
    
    #binding.pry()
    if @next_tile.nil?
      @next_tile = Tile.find(params[:last_tile_id])
      @discard_tiles = Rails.cache.read('discard_tiles')
      
      flash.now[:danger] = "残りツモ回数がありません。あなたの負けです。"
    else
      @select_tile = Tile.find(params[:tile_id])
      if @hand_tiles.include?(@select_tile)
        @hand_tiles.delete(@select_tile)
        @hand_tiles.append(Tile.find(params[:last_tile_id]))
      end
      
      if Rails.cache.exist?('discard_tiles')
        @discard_tiles = Rails.cache.read('discard_tiles')
      end
      @discard_tiles.append(@select_tile)
      #binding.pry()
      
      Rails.cache.write('hand_tiles', @hand_tiles)
      Rails.cache.write('rest_tiles', @rest_tiles)
      Rails.cache.write('discard_tiles', @discard_tiles)
    end
    render :test
  end
  
  def result
    
  end
  
  def tsumo
    hand_tiles = Tile.find(params[:hand]).sort()
    if canWin(hand_tiles)
      redirect_to '/game/result', success: '和了判定'
    else
      redirect_to '/game/result', danger: 'チョンボ判定'
    end
  end
  
  private
  def canWin(hand_tiles)
    # 手牌から雀頭候補リストを作成。
    # 雀頭を取り除き、面子候補を割り出す。
    hand_tiles_array = hand_tiles.map{ |tile| tile.value.to_s + tile.suit }
    pair_list = hand_tiles_array.filter{ |tile| hand_tiles_array.count(tile) > 1}.uniq
    
    # 七対子(seven pairs)判定。
    if pair_list.length == 7
      return true
    end
    
    # 4面子1雀頭判定ロジック
    # 1. 雀頭候補を割り出す。(oair)
    # 2. 刻子候補を割り出す。(triplets)
    # 3. 順子候補を割り出す。(sequences)
    pair_list.each do |pair_tile|
      # 雀頭を除いた手牌。
      tile_group = hand_tiles_array.clone
      tile_group[hand_tiles_array.index(pair_tile), 2] = []
      if isAllGroup(tile_group)
        return true
      end
    end
    
    return false
  end
  
  def isAllGroup(tile_group)
    # 刻子(同じ牌が3枚)リスト。
    triplets_list = tile_group.filter{ |tile| tile_group.count(tile) > 2}.uniq
    triplets_all_subset = [[]]
    
    # 刻子の和集合作成(刻子がない場合でも作成)。
    triplets_list.each do |triplets|
      triplets_all_subset_copy = triplets_all_subset.clone()
      triplets_all_subset_copy.each do |triplets_subset|
        triplets_all_subset.append [triplets].concat(triplets_subset)
      end
    end
    
    triplets_all_subset.each do |triplets_subset|
      tile_group_copy = tile_group.clone()
      
      # 刻子を取り除く。
      triplets_subset.each do |triplets|
        if tile_group_copy.include?(triplets)
          tile_group_copy[tile_group_copy.index(triplets), 3] = []
        end
      end
      
      # 順子の組み合わせ。
      while tile_group_copy.length > 0 do
        first_tile = tile_group_copy.first
        
        # 字牌は刻子のみ成り立つ。
        if first_tile.include?("z")
          break
        end
        
        next_sequences_tile = (first_tile[0].to_i + 1).to_s + first_tile[1]
        if !tile_group_copy.include?(next_sequences_tile)
          break
        end
        
        next_after_sequences_tile = (next_sequences_tile[0].to_i + 1).to_s + first_tile[1]
        if !tile_group_copy.include?(next_after_sequences_tile)
          break
        end
        
        # 順子を取り除く。
        tile_group_copy.delete_at tile_group_copy.index(first_tile)
        tile_group_copy.delete_at tile_group_copy.index(next_sequences_tile)
        tile_group_copy.delete_at tile_group_copy.index(next_after_sequences_tile)
      end
      
      # 4面子揃っている。
      if tile_group_copy.length == 0
        return true
      end
    end
    
    return false
  end
end
