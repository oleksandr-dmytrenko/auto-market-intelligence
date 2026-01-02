"""
Copart parser - парсинг HTML страниц Copart.com
"""
from bs4 import BeautifulSoup
from typing import List, Dict, Optional
import re
import time


class CopartParser:
    """Парсер для Copart.com"""
    
    BASE_URL = 'https://www.copart.com'
    
    @staticmethod
    def build_search_url(make: str = None, model: str = None, from_year: int = None, to_year: int = None, page: int = 1) -> str:
        """
        Строит URL для поиска на Copart
        
        Пример: https://www.copart.com/search?make=Audi&model=Q5&yearFrom=2021&yearTo=2023&page=1
        """
        params = []
        
        if make:
            params.append(f"make={make}")
        if model:
            params.append(f"model={model}")
        if from_year:
            params.append(f"yearFrom={from_year}")
        if to_year:
            params.append(f"yearTo={to_year}")
        
        # Добавляем пагинацию
        if page > 1:
            params.append(f"page={page}")
        
        query_string = "&".join(params)
        if query_string:
            return f"{CopartParser.BASE_URL}/search?{query_string}"
        else:
            return f"{CopartParser.BASE_URL}/search"
    
    @staticmethod
    def build_all_vehicles_url(page: int = 1) -> str:
        """
        Строит URL для получения всех автомобилей
        
        Args:
            page: Номер страницы
            
        Returns:
            URL для запроса
        """
        return f"{CopartParser.BASE_URL}/search?page={page}"
    
    @staticmethod
    def parse_listing_page(html: str) -> List[Dict]:
        """
        Парсит страницу со списком результатов Copart
        
        Возвращает список словарей с базовой информацией о каждом автомобиле
        """
        soup = BeautifulSoup(html, 'html.parser')
        listings = []
        seen_urls = set()
        
        # Copart использует различные форматы ссылок
        link_patterns = [
            r'/lot/[^/]+/\d+',  # /lot/YYYYMMDD/LOT_ID
            r'/vehicle/[^/]+/\d+',  # /vehicle/YYYYMMDD/LOT_ID
            r'/lot/\d+',  # /lot/LOT_ID
            r'/vehicle/\d+',  # /vehicle/LOT_ID
        ]
        
        # Ищем все ссылки на детальные страницы
        all_links = soup.find_all('a', href=True)
        
        for link in all_links:
            href = link.get('href', '')
            if not href:
                continue
            
            # Проверяем паттерны ссылок
            matches_pattern = any(re.search(pattern, href, re.I) for pattern in link_patterns)
            if not matches_pattern:
                continue
            
            # Нормализуем URL
            if href.startswith('/'):
                clean_href = f"{CopartParser.BASE_URL}{href}"
            elif href.startswith('http'):
                clean_href = href
            else:
                continue
            
            # Пропускаем дубликаты
            if clean_href in seen_urls:
                continue
            seen_urls.add(clean_href)
            
            # Извлекаем source_id (lot_id) из URL
            source_id = CopartParser._extract_source_id(clean_href)
            
            if not source_id or len(source_id) < 3:
                continue
            
            # Извлекаем базовую информацию из карточки
            listing_data = {
                'source': 'copart',
                'source_id': source_id,
                'lot_id': source_id,
                'detail_url': clean_href,
                'auction_url': clean_href,
                'raw_data': {}
            }
            
            # Пробуем извлечь данные из карточки на странице списка
            parent_card = link.find_parent(['div', 'article', 'li'], class_=re.compile(r'card|item|listing|vehicle', re.I))
            if parent_card:
                # Извлекаем make, model, year из текста карточки
                card_text = parent_card.get_text()
                
                # Пробуем найти год (4 цифры)
                year_match = re.search(r'\b(19|20)\d{2}\b', card_text)
                if year_match:
                    listing_data['year'] = int(year_match.group())
                
                # Пробуем найти make и model (обычно в заголовке)
                title_elem = parent_card.find(['h2', 'h3', 'h4', 'span'], class_=re.compile(r'title|heading|name', re.I))
                if title_elem:
                    title_text = title_elem.get_text(strip=True)
                    make_model = CopartParser._parse_title(title_text)
                    if make_model[0]:
                        listing_data['make'] = make_model[0]
                    if make_model[1]:
                        listing_data['model'] = make_model[1]
            
            listings.append(listing_data)
        
        return listings
    
    @staticmethod
    def parse_detail_page(html: str, detail_url: str) -> Dict:
        """
        Парсит детальную страницу автомобиля Copart
        
        Извлекает все данные: make, model, year, mileage, price, damage, location, VIN, фото
        """
        soup = BeautifulSoup(html, 'html.parser')
        
        source_id = CopartParser._extract_source_id(detail_url)
        data = {
            'source': 'copart',
            'source_id': source_id,
            'lot_id': source_id,
            'auction_url': detail_url,
            'auction_status': 'active',
            'raw_data': {}
        }
        
        # Извлекаем Stock #
        stock_number = CopartParser._extract_stock_number(soup)
        if stock_number:
            data['stock_number'] = stock_number
            data['raw_data']['stock_number'] = stock_number
        
        # Извлекаем VIN (полный или partial)
        vin = CopartParser._extract_vin(soup)
        if vin:
            data['vin'] = vin
            data['raw_data']['vin'] = vin
        
        # Извлекаем partial VIN отдельно
        partial_vin = CopartParser._extract_partial_vin(soup)
        if partial_vin:
            data['partial_vin'] = partial_vin
            data['raw_data']['partial_vin'] = partial_vin
        elif vin and len(vin) >= 11:
            # Если есть полный VIN, извлекаем partial из него
            data['partial_vin'] = vin[0:13]
        
        # Извлекаем заголовок (обычно содержит make, model, year)
        title = CopartParser._extract_title(soup)
        if title:
            make, model, year = CopartParser._parse_title(title)
            if make:
                data['make'] = make
            if model:
                data['model'] = model
            if year:
                data['year'] = year
            data['raw_data']['title'] = title
        
        # Извлекаем цену (текущая ставка или оценка)
        price = CopartParser._extract_price(soup)
        if price:
            data['price'] = price
        
        # Извлекаем пробег
        mileage = CopartParser._extract_mileage(soup)
        if mileage:
            data['mileage'] = mileage
        
        # Извлекаем цвет
        color = CopartParser._extract_color(soup)
        if color:
            data['color'] = color
        
        # Извлекаем тип повреждения
        damage_type = CopartParser._extract_damage(soup)
        if damage_type:
            data['damage_type'] = damage_type
        
        # Извлекаем локацию
        location = CopartParser._extract_location(soup)
        if location:
            data['location'] = location
        
        # Извлекаем дату окончания аукциона
        auction_end = CopartParser._extract_auction_end_date(soup)
        if auction_end:
            data['auction_end_date'] = auction_end
        
        # Извлекаем фото
        images = CopartParser._extract_images(soup)
        if images:
            data['images'] = images
            data['image_urls'] = images
        
        return data
    
    @staticmethod
    def _extract_source_id(url: str) -> str:
        """Извлекает source_id (lot_id) из URL Copart"""
        # Примеры:
        # - /lot/20240115/12345678 -> 12345678
        # - /vehicle/20240115/12345678 -> 12345678
        # - /lot/12345678 -> 12345678
        
        # Пробуем формат /lot/YYYYMMDD/LOT_ID или /vehicle/YYYYMMDD/LOT_ID
        match = re.search(r'/(?:lot|vehicle)/\d+/(\d+)', url, re.I)
        if match:
            return match.group(1)
        
        # Пробуем формат /lot/LOT_ID или /vehicle/LOT_ID
        match = re.search(r'/(?:lot|vehicle)/(\d+)', url, re.I)
        if match:
            return match.group(1)
        
        # Пробуем найти число в конце URL
        match = re.search(r'/(\d+)(?:\?|$)', url)
        if match:
            return match.group(1)
        
        return ''
    
    @staticmethod
    def _extract_stock_number(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает Stock # из HTML Copart"""
        # Ищем по label "Stock #" или "Lot #"
        stock_labels = soup.find_all(string=re.compile(r'Stock\s*#|Lot\s*#', re.I))
        for label in stock_labels:
            parent = label.parent
            if parent:
                # Ищем значение в следующем sibling или в том же элементе
                value_elem = parent.find_next_sibling(class_=re.compile(r'value|data-value', re.I))
                if not value_elem:
                    value_elem = parent.find('span', class_=re.compile(r'value|data-value', re.I))
                if not value_elem:
                    # Пробуем найти следующий элемент с классом text-bold
                    value_elem = parent.find_next('span', class_=re.compile(r'text-bold|bold', re.I))
                
                if value_elem:
                    stock_text = value_elem.get_text(strip=True)
                    if stock_text:
                        return stock_text
        
        # Альтернативный поиск: ищем в data-атрибутах
        data_items = soup.find_all(['div', 'span'], attrs={'data-label': re.compile(r'Stock|Lot', re.I)})
        for item in data_items:
            value = item.get('data-value') or item.get_text(strip=True)
            if value:
                return value
        
        return None
    
    @staticmethod
    def _extract_vin(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает VIN номер (полный или partial)"""
        # Ищем VIN в тексте (обычно 17 символов)
        text = soup.get_text()
        vin_pattern = r'\b([A-HJ-NPR-Z0-9]{17})\b'
        match = re.search(vin_pattern, text)
        if match:
            return match.group(1)
        
        # Ищем в специальных полях
        vin_labels = soup.find_all(string=re.compile(r'VIN|Vehicle Identification Number', re.I))
        for label in vin_labels:
            parent = label.parent
            if parent:
                next_sibling = parent.find_next_sibling()
                if next_sibling:
                    vin_text = next_sibling.get_text(strip=True)
                    # Проверяем полный VIN (17 символов)
                    if re.match(r'^[A-HJ-NPR-Z0-9]{17}$', vin_text):
                        return vin_text
                    # Проверяем partial VIN (11-13 символов, может быть с маскировкой)
                    partial_match = re.match(r'^([A-HJ-NPR-Z0-9]{11,13})', vin_text.replace('*', ''))
                    if partial_match:
                        return partial_match.group(1)
        
        # Ищем partial VIN с маскировкой (например: 1FMCU0G76FU******)
        partial_vin_pattern = r'\b([A-HJ-NPR-Z0-9]{11,13})\*+\b'
        match = re.search(partial_vin_pattern, text)
        if match:
            return match.group(1)
        
        return None
    
    @staticmethod
    def _extract_partial_vin(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает partial VIN (первые видимые символы)"""
        # Сначала пробуем извлечь полный VIN
        vin = CopartParser._extract_vin(soup)
        if vin:
            # Если VIN полный (17 символов), возвращаем первые 13
            if len(vin) >= 17:
                return vin[0:13]
            # Если уже partial (11-13 символов), возвращаем как есть
            if len(vin) >= 11:
                return vin[0:13]
        
        # Ищем partial VIN с маскировкой в HTML
        text = soup.get_text()
        # Паттерн для partial VIN с маскировкой: 1FMCU0G76FU******
        partial_pattern = r'\b([A-HJ-NPR-Z0-9]{11,13})\*+\b'
        match = re.search(partial_pattern, text)
        if match:
            return match.group(1)
        
        # Ищем в полях VIN с маскировкой
        vin_elements = soup.find_all(string=re.compile(r'VIN', re.I))
        for elem in vin_elements:
            parent = elem.parent
            if parent:
                vin_text = parent.get_text()
                # Ищем partial VIN в тексте
                partial_match = re.search(r'([A-HJ-NPR-Z0-9]{11,13})\*+', vin_text)
                if partial_match:
                    return partial_match.group(1)
        
        return None
    
    @staticmethod
    def _extract_title(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает заголовок"""
        # Пробуем разные селекторы для Copart
        title = soup.find('h1', class_=re.compile(r'title|heading|vehicle-title', re.I))
        if not title:
            title = soup.find('h1')
        if not title:
            title = soup.find(['h2', 'h3'], class_=re.compile(r'title|heading|vehicle-title', re.I))
        
        return title.get_text(strip=True) if title else None
    
    @staticmethod
    def _parse_title(title: str) -> tuple:
        """Парсит заголовок и извлекает make, model, year"""
        # Пример: "2023 Audi Q5 Premium 45 TFSI"
        parts = title.split()
        
        # Ищем год (4 цифры)
        year = None
        year_index = -1
        for i, part in enumerate(parts):
            if re.match(r'^(19|20)\d{2}$', part):
                year = int(part)
                year_index = i
                break
        
        # Make обычно после года или в начале
        # Model обычно после make
        if year_index >= 0:
            make = parts[year_index + 1] if len(parts) > year_index + 1 else None
            model = parts[year_index + 2] if len(parts) > year_index + 2 else None
            
            # Модель может состоять из нескольких слов
            if year_index + 3 < len(parts):
                model_parts = parts[year_index + 2:year_index + 4]
                model = ' '.join(model_parts)
        else:
            # Если год не найден, пробуем первые слова
            make = parts[0] if len(parts) > 0 else None
            model = parts[1] if len(parts) > 1 else None
        
        return (make, model, year)
    
    @staticmethod
    def _extract_price(soup: BeautifulSoup) -> Optional[float]:
        """Извлекает цену (текущая ставка или оценка)"""
        text = soup.get_text()
        price_patterns = [
            r'Current Bid:[\s]*\$?([\d,]+)',
            r'Bid:[\s]*\$?([\d,]+)',
            r'Estimate:[\s]*\$?([\d,]+)',
            r'\$[\s]*([\d,]+)',
            r'([\d,]+)[\s]*USD'
        ]
        
        for pattern in price_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                price_str = match.group(1).replace(',', '')
                try:
                    return float(price_str)
                except:
                    continue
        
        return None
    
    @staticmethod
    def _extract_mileage(soup: BeautifulSoup) -> Optional[int]:
        """Извлекает пробег"""
        text = soup.get_text()
        mileage_patterns = [
            r'Mileage:[\s]*([\d,]+)',
            r'Odometer:[\s]*([\d,]+)',
            r'([\d,]+)[\s]*miles',
            r'([\d,]+)[\s]*mi'
        ]
        
        for pattern in mileage_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                mileage_str = match.group(1).replace(',', '')
                try:
                    return int(mileage_str)
                except:
                    continue
        
        return None
    
    @staticmethod
    def _extract_color(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает цвет"""
        text = soup.get_text()
        color_patterns = [
            r'Color:[\s]*([A-Za-z]+)',
            r'Exterior Color:[\s]*([A-Za-z]+)',
            r'Paint:[\s]*([A-Za-z]+)'
        ]
        
        for pattern in color_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                return match.group(1).capitalize()
        
        return None
    
    @staticmethod
    def _extract_damage(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает тип повреждения"""
        text = soup.get_text()
        damage_patterns = [
            r'Damage:[\s]*([A-Za-z\s]+)',
            r'Damage Type:[\s]*([A-Za-z\s]+)',
            r'Condition:[\s]*([A-Za-z\s]+)'
        ]
        
        for pattern in damage_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                damage = match.group(1).strip()
                # Нормализуем типы повреждений
                damage_map = {
                    'none': 'None',
                    'no damage': 'None',
                    'minor': 'Minor',
                    'moderate': 'Moderate',
                    'severe': 'Severe',
                    'total loss': 'Total Loss',
                    'salvage': 'Salvage'
                }
                return damage_map.get(damage.lower(), damage.capitalize())
        
        return None
    
    @staticmethod
    def _extract_location(soup: BeautifulSoup) -> Optional[str]:
        """Извлекает локацию"""
        text = soup.get_text()
        location_patterns = [
            r'Location:[\s]*([A-Za-z\s,]+)',
            r'Sale Location:[\s]*([A-Za-z\s,]+)',
            r'Yard:[\s]*([A-Za-z\s,]+)'
        ]
        
        for pattern in location_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                return match.group(1).strip()
        
        return None
    
    @staticmethod
    def _extract_auction_end_date(soup: BeautifulSoup) -> Optional[float]:
        """Извлекает дату окончания аукциона"""
        text = soup.get_text()
        
        # Ищем паттерны даты
        date_patterns = [
            r'Auction Date:[\s]*([\d/]+)',
            r'Sale Date:[\s]*([\d/]+)',
            r'Ends:[\s]*([\d/]+)',
            r'End Date:[\s]*([\d/]+)'
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, text, re.I)
            if match:
                date_str = match.group(1)
                try:
                    # Пробуем распарсить дату
                    from datetime import datetime
                    date_obj = datetime.strptime(date_str, '%m/%d/%Y')
                    return date_obj.timestamp()
                except:
                    continue
        
        return None
    
    @staticmethod
    def _extract_images(soup: BeautifulSoup) -> List[str]:
        """Извлекает URL изображений"""
        images = []
        
        # Ищем изображения в различных местах
        img_tags = soup.find_all('img', src=True)
        
        for img in img_tags:
            src = img.get('src', '')
            if not src:
                continue
            
            # Нормализуем URL
            if src.startswith('/'):
                src = f"{CopartParser.BASE_URL}{src}"
            elif not src.startswith('http'):
                continue
            
            # Фильтруем только изображения автомобилей
            if any(keyword in src.lower() for keyword in ['vehicle', 'car', 'lot', 'image', 'photo', 'img']):
                if src not in images:
                    images.append(src)
        
        # Также ищем в data-атрибутах
        data_images = soup.find_all(['div', 'img'], attrs={'data-image': True})
        for elem in data_images:
            img_url = elem.get('data-image')
            if img_url and img_url.startswith('http') and img_url not in images:
                images.append(img_url)
        
        return images[:20]  # Ограничиваем до 20 изображений



